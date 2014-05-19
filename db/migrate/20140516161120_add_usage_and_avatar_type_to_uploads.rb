class AddUsageAndAvatarTypeToUploads < ActiveRecord::Migration
  def up
    add_column :uploads, :usage, :integer
    add_column :uploads, :avatar_type, :integer

    # usage: { image: 0, attachment: 1, avatar: 2, profile_background: 3 }
    # attachments
    execute "UPDATE uploads SET usage = 1 WHERE width IS NULL or height IS NULL"
    # avatar (check the users `uploaded_avatar_id`)
    execute "UPDATE uploads SET usage = 2 WHERE id IN (SELECT uploaded_avatar_id FROM users)"
    # profile_background (check the users `profile_background`)
    execute "UPDATE uploads SET usage = 3 WHERE url IN (SELECT profile_background FROM users WHERE profile_background <> '')"
    # image (all the rest is considered as an image)
    execute "UPDATE uploads SET usage = 0 WHERE usage IS NULL"

    # enum avatar_type: { gravatar: 1, uploaded: 2 }
    # only had uploaded avatar until now
    execute "UPDATE uploads SET avatar_type = 2 WHERE usage = 2"
  end

  def down
    remove_column :uploads, :usage
    remove_column :uploads, :avatar_type
  end
end
