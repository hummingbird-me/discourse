class AddAvatarTemplateToUsers < ActiveRecord::Migration
  def change
    add_column :users, :avatar_template, :string
  end
end
