require "avatar"

module Jobs

  class DownloadGravatar < Jobs::Base

    def execute(args)
      user_id = args[:user_id]
      raise Discourse::InvalidParameters.new(:user_id) if user_id.blank?

      user = User.find(user_id.to_i)

      Avatar.download_gravatar_for(user)
    end

  end

end
