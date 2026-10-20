class Forum::IndexPage < ForumLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs node : Node? = nil

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

      link(
        r("common.new_topic").t,
        to: Forum::New,
        class: "form-submit"
      ) if current_user
    end

    mount(
      Forum::List,
      topics: topics,
      pages: pages
    )
  end

  private def current_node : Node?
    node
  end
end
