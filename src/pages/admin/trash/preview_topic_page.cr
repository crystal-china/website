class Admin::Trash::PreviewTopicPage < AdminLayout
  include MarkdownFormatter

  needs topic : Topic
  needs comments : Array(Comment)
  needs pages : Lucky::Paginator

  def page_title : String
    r(".page_title").t(title: topic.title)
  end

  def admin_content : Nil
    section id: "trash-topic-preview" do
      header class: "mb-6 flex flex-wrap items-start justify-between gap-4" do
        div do
          h2 r(".page_title").t(title: topic.title), class: "m-0 break-words text-2xl font-semibold text-gray-900"
          para r(".description").t, class: "mt-2 mb-0 text-sm text-gray-600"
        end

        link(
          r(".back_to_trash").t,
          to: Admin::Trash::Index.with(kind: "topics"),
          class: "form-secondary"
        )
      end

      article class: "app-panel px-6 py-5" do
        header class: "mb-5 flex flex-wrap items-center gap-3 text-sm text-gray-500" do
          mount Shared::UserName, user: topic.user
          text topic.node.name
          local_time(
            topic.created_at,
            r("forum.show_page.posted_at").t(time: relative_time(topic.created_at))
          )
          render_deleted_at(topic.soft_deleted_at.not_nil!)
        end

        div class: "prose-neutral max-w-none prose text-base leading-7" do
          raw(topic.content_html || user_markdown(topic.content))
        end
      end

      h3 r(".comments").t, class: "mt-8 mb-4 text-lg font-semibold text-gray-900"

      if comments.empty?
        para r(".no_comments").t, class: "app-panel px-6 py-8 text-center text-gray-500"
      else
        comments.each do |comment|
          render_comment(comment)
        end
      end

      mount Shared::Pagination, pages: pages
    end
  end

  private def render_comment(comment : Comment) : Nil
    article id: "comment-#{comment.id}", class: "app-panel mt-4 px-6 py-5" do
      para class: "mt-0 mb-3 flex flex-wrap items-center gap-3 text-xs text-gray-500" do
        text "##{comment.id}"

        if (parent_id = comment.parent_id)
          text r(".reply_to").t(id: parent_id.to_s)
        end

        if (deleted_at = comment.soft_deleted_at)
          render_deleted_at(deleted_at)
        end
      end

      # 只复用正文展示，不挂载包含投票、回复和编辑按钮的 CardBody。
      mount(
        Comments::CardContent,
        formatter: formatter,
        comment: comment
      )
    end
  end

  private def render_deleted_at(at : Time) : Nil
    local_time(
      at,
      r("admin.trash.index_page.deleted_at").t(time: time_in_zone(at).to_s("%Y-%m-%d %H:%M:%S %z")),
      class: "text-red-700"
    )
  end
end
