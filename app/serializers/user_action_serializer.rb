class UserActionSerializer < ApplicationSerializer

  attributes :action_type,
             :created_at,
             :excerpt,
             :avatar_template,
             :acting_avatar_template,
             :slug,
             :topic_id,
             :target_user_id,
             :target_name,
             :target_username,
             :post_number,
             :reply_to_post_number,
             :username,
             :name,
             :user_id,
             :acting_username,
             :acting_name,
             :acting_user_id,
             :title,
             :deleted,
             :hidden,
             :moderator_action,
             :edit_reason

  def excerpt
    PrettyText.excerpt(object.cooked, 300) if object.cooked
  end

  def include_name?
    SiteSetting.enable_names?
  end

  def include_target_name?
    include_name?
  end

  def include_acting_name?
    include_name?
  end

  def slug
    Slug.for(object.title)
  end

  def moderator_action
    object.post_type == Post.types[:moderator_action]
  end

  def include_reply_to_post_number?
    object.action_type == UserAction::REPLY
  end

  def include_edit_reason?
    object.action_type == UserAction::EDIT
  end

end
