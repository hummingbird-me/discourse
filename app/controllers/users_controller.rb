require_dependency 'discourse_hub'
require_dependency 'user_name_suggester'
require_dependency 'avatar_upload_service'

class UsersController < ApplicationController

  skip_before_filter :authorize_mini_profiler, only: [:avatar]
  skip_before_filter :check_xhr, only: [:show, :password_reset, :update, :activate_account, :authorize_email, :user_preferences_redirect, :avatar, :my_redirect]

  before_filter :ensure_logged_in, only: [:username, :update, :change_email, :user_preferences_redirect, :upload_user_image, :toggle_avatar, :clear_profile_background, :destroy]
  before_filter :respond_to_suspicious_request, only: [:create]

  # we need to allow account creation with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_filter :verify_authenticity_token, only: [:create]
  skip_before_filter :redirect_to_login_if_required, only: [:check_username,
                                                            :create,
                                                            :get_honeypot_value,
                                                            :activate_account,
                                                            :send_activation_email,
                                                            :authorize_email,
                                                            :password_reset]

  def show
    @user = fetch_user_from_params
    user_serializer = UserSerializer.new(@user, scope: guardian, root: 'user')
    respond_to do |format|
      format.html do
        store_preloaded("user_#{@user.username}", MultiJson.dump(user_serializer))
      end

      format.json do
        render_json_dump(user_serializer)
      end
    end
  end

  def user_preferences_redirect
    redirect_to email_preferences_path(current_user.username_lower)
  end

  def update
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
    json_result(user, serializer: UserSerializer) do |u|
      updater = UserUpdater.new(current_user, user)
      updater.update(params)
    end
  end

  def username
    params.require(:new_username)

    user = fetch_user_from_params
    guardian.ensure_can_edit_username!(user)

    result = user.change_username(params[:new_username])
    raise Discourse::InvalidParameters.new(:new_username) unless result

    render nothing: true
  end

  def badge_title
    params.require(:user_badge_id)

    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user_badge = UserBadge.find(params[:user_badge_id])
    if user_badge.user == user && user_badge.badge.allow_title?
      user.title = user_badge.badge.name
      user.save!
    end

    render nothing: true
  end

  def preferences
    render nothing: true
  end

  def my_redirect
    if current_user.present? && params[:path] =~ /^[a-z\-]+$/
      redirect_to "/users/#{current_user.username}/#{params[:path]}"
      return
    end
    raise Discourse::NotFound.new
  end

  def invited
    inviter = fetch_user_from_params

    invites = if guardian.can_see_invite_details?(inviter)
      Invite.find_all_invites_from(inviter)
    else
      Invite.find_redeemed_invites_from(inviter)
    end

    invites = invites.filter_by(params[:filter])
    render_json_dump invites: serialize_data(invites.to_a, InviteSerializer),
                     can_see_invite_details: guardian.can_see_invite_details?(inviter)
  end

  def is_local_username
    params.require(:username)
    u = params[:username].downcase
    r = User.exec_sql('select 1 from users where username_lower = ?', u).values
    render json: {valid: r.length == 1}
  end

  def render_available_true
    render(json: { available: true })
  end

  def changing_case_of_own_username(target_user, username)
    target_user and username.downcase == target_user.username.downcase
  end

  # Used for checking availability of a username and will return suggestions
  # if the username is not available.
  def check_username
    if !params[:username].present?
      params.require(:username) if !params[:email].present?
      return render(json: success_json) unless SiteSetting.call_discourse_hub?
    end
    username = params[:username]

    target_user = user_from_params_or_current_user

    # The special case where someone is changing the case of their own username
    return render_available_true if changing_case_of_own_username(target_user, username)

    checker = UsernameCheckerService.new
    email = params[:email] || target_user.try(:email)
    render json: checker.check_username(username, email)
  rescue RestClient::Forbidden
    render json: {errors: [I18n.t("discourse_hub.access_token_problem")]}
  end

  def user_from_params_or_current_user
    params[:for_user_id] ? User.find(params[:for_user_id]) : current_user
  end

  def create
    user = User.new(user_params)

    authentication = UserAuthenticator.new(user, session)

    if !authentication.has_authenticator? && !SiteSetting.enable_local_logins
      render nothing: true, status: 500
      return
    end

    authentication.start

    activation = UserActivator.new(user, request, session, cookies)
    activation.start

    # just assign a password if we have an authenticator and no password
    # this is the case for Twitter
    user.password = SecureRandom.hex if user.password.blank? && authentication.has_authenticator?

    if user.save
      authentication.finish
      activation.finish

      render json: {
        success: true,
        active: user.active?,
        message: activation.message
      }
    else
      render json: {
        success: false,
        message: I18n.t(
          'login.errors',
          errors: user.errors.full_messages.join("\n")
        ),
        errors: user.errors.to_hash,
        values: user.attributes.slice('name', 'username', 'email')
      }
    end
  rescue ActiveRecord::StatementInvalid
    render json: {
      success: false,
      message: I18n.t("login.something_already_taken")
    }
  rescue DiscourseHub::UsernameUnavailable => e
    render json: e.response_message
  rescue RestClient::Forbidden
    render json: { errors: [I18n.t("discourse_hub.access_token_problem")] }
  end

  def get_honeypot_value
    render json: {value: honeypot_value, challenge: challenge_value}
  end

  def password_reset
    expires_now()

    @user = EmailToken.confirm(params[:token])
    if @user.blank?
      flash[:error] = I18n.t('password_reset.no_token')
    elsif request.put?
      raise Discourse::InvalidParameters.new(:password) unless params[:password].present?
      @user.password = params[:password]
      @user.password_required!
      if @user.save
        Invite.invalidate_for_email(@user.email) # invite link can't be used to log in anymore
        logon_after_password_reset
      end
    end
    render layout: 'no_js'
  end

  def logon_after_password_reset
    message = if Guardian.new(@user).can_access_forum?
                # Log in the user
                log_on_user(@user)
                'password_reset.success'
              else
                @requires_approval = true
                'password_reset.success_unapproved'
              end

    flash[:success] = I18n.t(message)
   end

  def change_email
    params.require(:email)
    user = fetch_user_from_params
    guardian.ensure_can_edit_email!(user)
    lower_email = Email.downcase(params[:email]).strip

    # Raise an error if the email is already in use
    if User.where("email = ?", lower_email).exists?
      raise Discourse::InvalidParameters.new(:email)
    end

    email_token = user.email_tokens.create(email: lower_email)
    Jobs.enqueue(
      :user_email,
      to_address: lower_email,
      type: :authorize_email,
      user_id: user.id,
      email_token: email_token.token
    )

    render nothing: true
  end

  def authorize_email
    expires_now()
    if @user = EmailToken.confirm(params[:token])
      log_on_user(@user)
    else
      flash[:error] = I18n.t('change_email.error')
    end
    render layout: 'no_js'
  end

  def activate_account
    expires_now()
    if @user = EmailToken.confirm(params[:token])

      # Log in the user unless they need to be approved
      if Guardian.new(@user).can_access_forum?
        @user.enqueue_welcome_message('welcome_user') if @user.send_welcome_message
        log_on_user(@user)
      else
        @needs_approval = true
      end

    else
      flash[:error] = I18n.t('activation.already_done')
    end
    render layout: 'no_js'
  end

  def send_activation_email
    @user = fetch_user_from_params
    @email_token = @user.email_tokens.unconfirmed.active.first
    enqueue_activation_email if @user
    render nothing: true
  end

  def enqueue_activation_email
    @email_token ||= @user.email_tokens.create(email: @user.email)
    Jobs.enqueue(:user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
  end

  def search_users
    term = params[:term].to_s.strip
    topic_id = params[:topic_id]
    topic_id = topic_id.to_i if topic_id

    results = UserSearch.new(term, topic_id: topic_id, searching_user: current_user).search

    user_fields = [:username, :avatar_template]
    user_fields << :name if SiteSetting.enable_names?

    to_render = { users: results.as_json(only: user_fields) }

    if params[:include_groups] == "true"
      to_render[:groups] = Group.search_group(term, current_user).map { |m| { name: m.name, usernames: m.usernames.split(",") } }
    end

    render json: to_render
  end

  # LEGACY: used by the API
  def upload_avatar
    params[:user_image_type] = "avatar"
    upload_user_image
  end

  def avatars
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    avatars = { generated: Avatar.css_avatar_template(user.username) }

    gravatar = user.gravatar
    avatars[:gravatar] = {
      external: Avatar.gravatar_template(user.email),
      local: gravatar ? Avatar.img_avatar_template(gravatar.url) : nil
    }

    uploaded = SiteSetting.allow_uploaded_avatars ? user.uploaded_avatar : nil
    avatars[:uploaded] = uploaded ? Avatar.img_avatar_template(uploaded.url) : nil

    render json: avatars
  end

  def update_gravatar
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    Jobs.enqueue(:download_gravatar, user_id: user.id)

    render nothing: true
  end

  def select_avatar
    params.require(:avatar_type)
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user.avatar_type = params[:avatar_type].to_i

    case user.avatar_type
    when Avatar.types[:gravatar]
      user.avatar_url = Discourse.store.avatar_template(user.gravatar)
    when Avatar.types[:uploaded]
      user.avatar_url = Discourse.store.avatar_template(user.uploaded_avatar)
    else
      user.avatar_url = nil
    end

    user.avatar_template = Avatar.avatar_template_for(user)
    user.save

    render nothing: true
  end

  def upload_user_image
    params.require(:user_image_type)
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    file = params[:file] || params[:files].first

    begin
      image = build_user_image_from(file)
    rescue Discourse::InvalidParameters
      return render status: 422, text: I18n.t("upload.images.unknown_image_type")
    end

    # set the appropriate usage
    options = { usage: Upload.usages[params[:user_image_type].to_sym] }
    options[:avatar_type] = Upload.avatar_types[:uploaded] if params[:user_image_type] == "avatar"
    # create the upload
    upload = Upload.create_for(user.id, image.file, image.filename, image.filesize, options)

    if upload.errors.empty?
      case params[:user_image_type]
      when "avatar"
        user.upload_avatar!(upload)
        render json: { template: user.avatar_template, width: upload.width, height: upload.height }
      when "profile_background"
        user.upload_profile_background!(upload)
        render json: { url: upload.url, width: upload.width, height: upload.height }
      end
    else
      render status: 422, text: upload.errors.full_messages
    end
  end

  def clear_profile_background
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user.profile_background.delete if user.profile_background
    user.profile_background_url = nil
    user.save!

    render nothing: true
  end

  def destroy
    @user = fetch_user_from_params
    guardian.ensure_can_delete_user!(@user)

    UserDestroyer.new(current_user).destroy(@user, {delete_posts: true, context: params[:context]})

    render json: success_json
  end

  private

    def honeypot_value
      Digest::SHA1::hexdigest("#{Discourse.current_hostname}:#{Discourse::Application.config.secret_token}")[0,15]
    end

    def challenge_value
      challenge = $redis.get('SECRET_CHALLENGE')
      unless challenge && challenge.length == 16*2
        challenge = SecureRandom.hex(16)
        $redis.set('SECRET_CHALLENGE',challenge)
      end

      challenge
    end

    def build_user_image_from(file)
      source = if file.is_a?(String)
                 is_api? ? :url : (raise Discourse::InvalidParameters)
               else
                 :image
               end

      AvatarUploadService.new(file, source)
    end

    def respond_to_suspicious_request
      if suspicious?(params)
        render(
          json: {
            success: true,
            active: false,
            message: I18n.t("login.activate_email", email: params[:email])
          }
        )
      end
    end

    def suspicious?(params)
      honeypot_or_challenge_fails?(params) || SiteSetting.invite_only?
    end

    def honeypot_or_challenge_fails?(params)
      params[:password_confirmation] != honeypot_value ||
        params[:challenge] != challenge_value.try(:reverse)
    end

    def user_params
      params.permit(
        :name,
        :email,
        :password,
        :username,
        :active
      ).merge(ip_address: request.ip, registration_ip_address: request.ip)
    end
end
