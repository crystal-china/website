class Forum::Index < ForumAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param node : String?
  param following : Bool = false

  before require_sign_in_for_following

  get "/forum" do
    query = TopicQuery.new

    if following && (me = current_user)
      query = query.join_topic_follows(TopicFollowQuery.new.follower_id(me.id))
    end

    if (node_slug = node)
      current_node = NodeQuery.new.slug(node_slug).first?
      query = query.node_id(current_node.id) if current_node
    end

    query = query.last_active_at.desc_order.id.desc_order.preload_user.preload_node.preload_last_reply_user
    pages, topics = paginate(query, per_page: 20)

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Forum::List,
        topics: topics,
        pages: pages,
        followed_topics: following,
        current_user: current_user
      )
    end

    html(
      Forum::IndexPage,
      topics: topics,
      pages: pages,
      node: current_node,
      followed_topics: following
    )
  end

  private def require_sign_in_for_following : Lucky::Response | Lucky::ActionPipes::Continue
    return continue unless following

    require_sign_in
  end
end
