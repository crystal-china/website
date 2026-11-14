@[Rosetta::Translatable::Config(prefix: "forum.index_page")]
class Forum::ListHeader < BaseComponent
  needs node : Node? = nil
  needs followed_topics : Bool = false
  needs only_show_unread : Bool = false

  def self.page_title(node : Node?) : String
    node.try { |current_node| Rosetta.find("forum.index_page.node_title").t(name: current_node.name) } || Rosetta.find("common.community").t
  end

  def render : Nil
    current_node = node
    heading = current_node.try(&.name) || r("common.community").t
    description = current_node.try(&.summary) || r(".description").t

    header id: "forum-list-header", class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
      div do
        h1 heading, class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
        para description, class: "mt-2 mb-0 text-sm text-gray-600"
      end

      if current_user
        div class: "flex flex-wrap items-center gap-3" do
          div(
            class: "flex flex-wrap items-center gap-3",
            "hx-target:inherited": "#forum-content",
            "hx-swap:inherited": "outerHTML show:top showTarget:body",
            "hx-sync:inherited": "#forum-content:replace"
          ) do
            render_follow_filter
            render_unread_filter
          end

          link(
            r("common.new_topic").t,
            to: Forum::New,
            class: "form-submit"
          )
        end
      end
    end
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
