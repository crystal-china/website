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

    # 保存时可能产生 @自己的通知，直接返回的详情页需使用更新后的铃铛计数。
    render_topic(topic, current_user: current_user.try(&.reload))
  end

  # html 的 expose 使用同名参数；保存后传入新对象，普通访问沿用当前用户。
  private def render_topic(
    topic : Topic,
    *,
    followed_topics : Bool = false,
    current_user : User? = self.current_user,
  ) : Lucky::Response
    comment_thread = CommentThreadQuery.new.topic_id(topic.id).first
    can_delete_topic = false
    following = false

    if (me = current_user)
      can_delete_topic = me.admin? || (me.id == topic.user_id && topic.replies_count.zero?)
      following = TopicFollowQuery.new.topic_id(topic.id).follower_id(me.id).any? if me.id != topic.user_id
    end

    html(
      Forum::ShowPage,
      topic: topic,
      comment_thread: comment_thread,
      can_delete_topic: can_delete_topic,
      following: following,
      followed_topics: followed_topics
    )
  end
end
