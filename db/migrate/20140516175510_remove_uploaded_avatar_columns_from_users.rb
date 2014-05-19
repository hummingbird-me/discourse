class RemoveUploadedAvatarColumnsFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :uploaded_avatar_template, :string
    remove_column :users, :uploaded_avatar_id, :integer
    remove_column :users, :use_uploaded_avatar, :boolean, default: false
  end
end
