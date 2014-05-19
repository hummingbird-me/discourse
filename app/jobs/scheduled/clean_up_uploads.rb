module Jobs

  class CleanUpUploads < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.clean_up_uploads?

      uploads_used_in_posts = PostUpload.uniq.pluck(:upload_id)
      uploads_used_as_avatars = Upload.avatar.pluck(:id)
      uploads_used_as_profile_backgrounds = Upload.profile_background.pluck(:id)

      upload_ids = uploads_used_in_posts +
                   uploads_used_as_avatars +
                   uploads_used_as_profile_backgrounds

      upload_ids.uniq!

      grace_period = [SiteSetting.clean_orphan_uploads_grace_period_hours, 1].max

      Upload.where("created_at < ?", grace_period.hour.ago)
            .where("id NOT IN (?)", upload_ids)
            .find_each do |upload|
        upload.destroy
      end

    end

  end

end
