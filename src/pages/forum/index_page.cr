class Forum::IndexPage < ForumLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs node : Node? = nil
  needs unread_topic_ids : Set(Int64) = Set(Int64).new

  def page_title : String
    Forum::ListHeader.page_title(node)
  end

  def forum_content : Nil
    mount(
      Forum::ListHeader,
      node: node,
      followed_topics: followed_topics?,
      only_show_unread: only_show_unread?
    )

    mount(
      Forum::List,
      topics: topics,
      pages: pages,
      followed_topics: followed_topics?,
      only_show_unread: only_show_unread?,
      unread_topic_ids: unread_topic_ids
    )
  end

  private def current_node : Node?
    node
  end
end
