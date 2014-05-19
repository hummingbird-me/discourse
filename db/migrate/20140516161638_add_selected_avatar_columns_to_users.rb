class AddSelectedAvatarColumnsToUsers < ActiveRecord::Migration
  def up
    add_column :users, :avatar_type, :integer, default: 0, null: false
    add_column :users, :avatar_template, :string
    add_column :users, :avatar_url, :string

    # Avatar.types { generated: 0, gravatar: 1, uploaded: 2 }

    # update type & avatar_url for uploaded avatars
    execute "UPDATE users
             SET avatar_type = 2,
                 avatar_url = replace(uploaded_avatar_template, '{size}', '{raw_size}')
             WHERE use_uploaded_avatar = 't'
               AND uploaded_avatar_template <> ''"

    # update type & avatar_url for custom gravatars
    execute "WITH users_with_custom_gravatar AS (SELECT user_id FROM user_stats WHERE has_custom_avatar = 't')
             UPDATE users
             SET avatar_type = 1,
                 avatar_url = '//www.gravatar.com/avatar/' || md5(lower(trim(email))) || '.png?s={raw_size}&r=pg&d=identicon'
             WHERE use_uploaded_avatar = 'f'
               AND id IN (SELECT user_id FROM users_with_custom_gravatar)"

    # set the template for both uploaded/gravatars
    execute "UPDATE users
             SET avatar_template = '<img width=\"{size}\" height=\"{size}\" class=\"{class}\" title=\"{title}\" src=\"' || avatar_url || '\">'
             WHERE avatar_url <> ''"

    # set the default template for the rest
    sql = <<-SQL
      UPDATE users
      SET avatar_template = '<i class=\"avatar avatar-color-' || ('x0' || md5(username))::bit(64)::bigint % 216 || ' avatar-{size} {class}\" title=\"{title}\">' || substring(username for 1) || '</i>'
      WHERE avatar_type = 0
    SQL

    execute sql
  end

  def down
    remove_column :users, :avatar_type
    remove_column :users, :avatar_template
    remove_column :users, :avatar_url
  end
end
