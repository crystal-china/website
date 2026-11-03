class Forum::Index < ForumAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param node : String?
  param following : Bool = false

  before require_sign_in_for_following

  get "/forum" do
    query = TopicQuery.new

    if following && (me = current_user)
      query = query.join_topic_follows(followed_topic_query(me.id))
    end

    if (node_slug = node)
      current_node = NodeQuery.new.slug(node_slug).first?
      query = query.node_id(current_node.id) if current_node
    end

    query = query.last_active_at.desc_order.id.desc_order.preload_user.preload_node.preload_last_reply_user

    if following
      # 关注可与节点组合，不能使用站点/节点的总数。
      pages, topics = paginate(query, per_page: 20)
    else
      item_count = current_node ? current_node.topics_count : Space::BaseQuery.find(Space::DEFAULT_ID).topics_count
      pages = Lucky::Paginator.new(
        page: paginator_page,
        per_page: 20,
        item_count: item_count,
        full_path: context.request.resource
      )
      topics = query.limit(pages.per_page).offset(pages.offset)
    end

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Forum::List,
        topics: topics,
        pages: pages,
        followed_topics: following,
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
