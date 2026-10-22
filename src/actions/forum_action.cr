abstract class ForumAction < BrowserAction
  expose nodes

  private def nodes : Array(Node)
    NodeQuery.new.sorted.results
  end

  private def render_saved_topic(topic : Topic) : Lucky::Response
    path = Forum::Show.with(id: topic.id).path

    return redirect to: path unless context.request.headers["HX-Request-Type"]?

    topic = TopicQuery.new.id(topic.id).preload_user.preload_node.first

    context.response.headers["X-Draft-Saved"] = "true"
    context.response.headers["HX-Push-Url"] = path

    render_topic(topic)
  end

  private def render_topic(topic : Topic) : Lucky::Response
    comment_thread = CommentThreadQuery.new.topic_id(topic.id).first
    can_delete_topic = false
    following = false

    if (me = current_user)
      can_delete_topic = me.admin? || (me.id == topic.user_id && !comment_thread.comments_query.with_soft_deleted.any?)
      following = TopicFollowQuery.new.topic_id(topic.id).follower_id(me.id).any? if me.id != topic.user_id
    end

    html(
      Forum::ShowPage,
      topic: topic,
      comment_thread: comment_thread,
      can_delete_topic: can_delete_topic,
      following: following
    )
  end
end
