class Forum::Index < ForumAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param node : String?
  param following : Bool = false
  param only_show_unread : Bool = false

  before require_sign_in_for_filters

  get "/forum" do
    query = TopicQuery.new
    me = current_user

    if following && me
      query = query.join_topic_follows(followed_topic_query(me.id))
    end

    if only_show_unread && me
      query = query.unread_by(me.id).last_active_at.gte(Time.utc - TopicReading::UNREAD_PERIOD)
    end

    if (node_slug = node)
      current_node = NodeQuery.new.slug(node_slug).first?
      query = query.node_id(current_node.id) if current_node
    end

    query = query.last_active_at.desc_order.id.desc_order.preload_user.preload_node.preload_last_reply_user

    if following || only_show_unread
      # 关注可以按照节点过滤，未读会受七天窗口影响，所以，不使用 counter
      pages, topics = paginate(query, per_page: App::DEFAULT_PER_PAGE)
    else
      item_count = current_node ? current_node.topics_count : Space::BaseQuery.find(Space::DEFAULT_ID).topics_count
      pages = Lucky::Paginator.new(
        page: paginator_page,
        per_page: App::DEFAULT_PER_PAGE,
        item_count: item_count,
        full_path: context.request.resource
      )
      topics = query.limit(pages.per_page).offset(pages.offset)
    end

    topic_ids = topics.results.map(&.id)
    unread_topic_ids = Set(Int64).new

    if me && !topic_ids.empty?
      # 只检查本页主题，一次查询取得未读标记，不逐条查询阅读记录或评论。
      unread_topic_ids = if only_show_unread
                           topic_ids.to_set
                         else
                           TopicReading.unread_ids(
                             user_id: me.id,
                             topic_ids: topic_ids
                           )
                         end
    end

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Forum::List,
        topics: topics,
        pages: pages,
        followed_topics: following,
        only_show_unread: only_show_unread,
        unread_topic_ids: unread_topic_ids
      )
    end

    html(
      Forum::IndexPage,
      topics: topics,
      pages: pages,
      node: current_node,
      followed_topics: following,
      only_show_unread: only_show_unread,
      unread_topic_ids: unread_topic_ids
    )
  end

  private def require_sign_in_for_filters : Lucky::Response | Lucky::ActionPipes::Continue
    return continue unless following || only_show_unread

    require_sign_in
  end
end
