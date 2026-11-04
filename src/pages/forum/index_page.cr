class Forum::IndexPage < ForumLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs node : Node? = nil
  needs unread_topic_ids : Set(Int64) = Set(Int64).new

  def page_title : String
    node.try { |current_node| r(".node_title").t(name: current_node.name) } || r("common.community").t
  end

  def forum_content : Nil
    current_node = node

    heading = current_node.try(&.name) || r("common.community").t
    description = current_node.try(&.summary) || r(".description").t

    header class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
      div do
        h1 heading, class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
        para description, class: "mt-2 mb-0 text-sm text-gray-600"
      end

      if current_user
        div class: "flex flex-wrap items-center gap-3" do
          render_follow_filter
          render_unread_filter

          link(
            r("common.new_topic").t,
            to: Forum::New,
            class: "form-submit"
          )
        end
      end
    end

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

  private def render_follow_filter : Nil
    all_path = Forum::Index.with(
      node: node.try(&.slug),
      only_show_unread: only_show_unread? ? true : nil
    ).path
    following_path = Forum::Index.with(
      node: node.try(&.slug),
      following: true,
      only_show_unread: only_show_unread? ? true : nil
    ).path

    mount(
      Shared::Toggle,
      options: [{r(".all").t, all_path}, {r(".following").t, following_path}],
      selected: followed_topics? ? following_path : all_path
    )
  end

  private def render_unread_filter : Nil
    all_path = Forum::Index.with(
      node: node.try(&.slug),
      following: followed_topics? ? true : nil
    ).path
    unread_path = Forum::Index.with(
      node: node.try(&.slug),
      following: followed_topics? ? true : nil,
      only_show_unread: true
    ).path

    mount(
      Shared::Toggle,
      options: [{r(".all_read_states").t, all_path}, {r(".only_unread").t, unread_path}],
      selected: only_show_unread? ? unread_path : all_path
    )
  end
end
