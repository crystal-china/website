class Forum::Show < ForumAction
  include Auth::AllowGuests

  get "/forum/:id" do
    topic = TopicQuery.new.id(id).preload_user.preload_node.first?

    if topic.nil?
      return html_with_status Errors::ContentUnavailablePage, 404, content_name: "主题"
    end

    comment_thread = CommentThreadQuery.new.topic_id(topic.id).first
    can_delete_topic = false

    if (me = current_user)
      can_delete_topic = me.admin? || (me.id == topic.user_id && !comment_thread.comments_query.with_soft_deleted.any?)
    end

    html Forum::ShowPage, topic: topic, comment_thread: comment_thread, can_delete_topic: can_delete_topic
  end
end
