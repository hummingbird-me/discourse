class RenameProfileBackgroundColumnOnUsers < ActiveRecord::Migration
  def change
    rename_column :users, :profile_background, :profile_background_url
  end
end
