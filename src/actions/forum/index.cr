class Forum::Index < ForumAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param node : String?

  get "/forum" do
    query = TopicQuery.new.last_active_at.desc_order.id.desc_order.preload_user.preload_node.preload_last_reply_user

    if (node_slug = node)
      current_node = NodeQuery.new.slug(node_slug).first?
      query = query.node_id(current_node.id) if current_node
    end

    pages, topics = paginate(
      query,
      per_page: 20
    )

    html Forum::IndexPage, topics: topics, pages: pages, node: current_node
  end
end
