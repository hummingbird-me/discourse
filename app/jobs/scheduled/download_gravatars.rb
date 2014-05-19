require "avatar"

module Jobs

  class DownloadGravatars < Jobs::Scheduled
    every 1.hour

    def execute(args)
      User.where("avatar_type = #{Avatar.types[:gravatar]} AND avatar_url LIKE '%www.gravatar.com%'").each do |user|
        begin
          Avatar.download_gravatar_for(user)
        rescue
          puts "Could not download the gravatar (#{gravatar_url}) for user ##{user.id}"
        end
      end
    end

  end

end
