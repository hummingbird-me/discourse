require "url_helper"
require "avatar_upload_service"

class Avatar

  def self.types
    @@types ||= Enum.new(:generated, :gravatar, :uploaded, start: 0)
  end

  # TODO: should be set: User.gravatar_url_for_template(id == -1 ? "team@discourse.org" : email)

  def self.gravatar_template(email)
    img_avatar_template(gravatar_url_for_template(email))
  end

  def self.gravatar_url_for_template(email)
    email_hash = self.email_hash(email)
    "//www.gravatar.com/avatar/#{email_hash}.png?s={raw_size}&r=pg&d=identicon"
  end

  def self.email_hash(email)
    Digest::MD5.hexdigest(email.strip.downcase)
  end

  def self.css_avatar_template(username)
    initial = username.first
    color = Digest::MD5.hexdigest(username)[0...15].to_i(16) % 216
    "<i class='avatar avatar-{size} avatar-color-#{color} {class}' title='{title}'>#{initial}</i>"
  end

  def self.img_avatar_template(url)
    url = UrlHelper.schemaless UrlHelper.absolute url
    "<img width='{size}' height='{size}' class='{class}' title='{title}' src='#{url}'>"
  end

  def self.avatar_template_for(user)
    case user.avatar_type
    when Avatar.types[:gravatar], Avatar.types[:uploaded]
      img_avatar_template(user.avatar_url)
    else
      css_avatar_template(user.username)
    end
  end

  def self.download_gravatar_for(user)
    # url to the largest size we need
    gravatar_url = "http:" + self.gravatar_url_for_template(user.email).gsub("{raw_size}", "240")
    # download the gravatar
    avatar = AvatarUploadService.new(gravatar_url, :url)
    # create the upload
    options = { usage: Upload.usages[:avatar], avatar_type: Upload.avatar_types[:gravatar] }
    upload = Upload.create_for(user.id, avatar.file, avatar.filename, avatar.filesize, options)
    # set the avatar
    user.upload_gravatar!(upload)
  end

end
