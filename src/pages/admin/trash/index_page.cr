class Admin::Trash::IndexPage < AdminLayout
  needs kind : String
  needs comments : Array(Comment)
  needs topics : Array(Topic)
  needs pages : Lucky::Paginator

  def page_title : String
    "回收站"
  end

  def admin_content : Nil
    header class: "mb-6" do
      h2 "回收站", class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
      para "删除的内容保留在数据库中，可由管理员恢复。", class: "mt-1.5 mb-0 text-sm text-gray-600"
    end

    nav class: "mb-5 flex gap-3", "aria-label": "回收站分类" do
      link "评论", to: Admin::Trash::Index, class: kind == "comments" ? "form-submit" : "form-secondary"
      link "主题", to: Admin::Trash::Index.with(kind: "topics"), class: kind == "topics" ? "form-submit" : "form-secondary"
    end

    if kind == "comments"
      render_comments
    else
      render_topics
    end

    render_pagination unless pages.one_page?
  end

  private def render_comments : Nil
    if comments.empty?
      para "没有已删除的评论。", class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        comments.each do |comment|
          article class: "flex flex-wrap items-start justify-between gap-4 px-6 py-4" do
            div class: "min-w-0 flex-1" do
              thread = comment.comment_thread
              source = thread.topic_id ? "主题 ##{thread.topic_id}" : "文档 ##{thread.doc_id}"

              para class: "m-0 text-xs text-gray-500" do
                text "评论 ##{comment.id} · "
                mount Shared::UserName, user: comment.user
                text " · #{source}"
              end
              para comment.content[0, 160], class: "mt-1 mb-0 whitespace-pre-wrap break-words text-sm text-gray-800"
              span deleted_at_text(comment.soft_deleted_at.not_nil!), class: "mt-2 block text-xs text-gray-500"
            end

            form_for Admin::Trash::RestoreComment.with(id: comment.id) do
              submit "恢复", class: "form-secondary"
            end
          end
        end
      end
    end
  end

  private def render_topics : Nil
    if topics.empty?
      para "没有已删除的主题。", class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        topics.each do |topic|
          article class: "flex flex-wrap items-start justify-between gap-4 px-6 py-4" do
            div class: "min-w-0 flex-1" do
              h3 topic.title, class: "m-0 text-base font-semibold text-gray-900"
              para class: "mt-1 mb-0 text-xs text-gray-500" do
                text "##{topic.id} · "
                mount Shared::UserName, user: topic.user
                text " · #{deleted_at_text(topic.soft_deleted_at.not_nil!)}"
              end
            end

            form_for Admin::Trash::RestoreTopic.with(id: topic.id) do
              submit "恢复", class: "form-secondary"
            end
          end
        end
      end
    end
  end

  private def deleted_at_text(at : Time) : String
    "删除于 #{at.to_local.to_s("%Y-%m-%d %H:%M")}"
  end

  private def render_pagination : Nil
    nav class: "mt-6 flex items-center justify-center gap-4 text-sm", "aria-label": "回收站分页" do
      if (previous_path = pages.path_to_previous)
        a "上一页", href: previous_path, class: "form-secondary"
      end

      span "第 #{pages.page} / #{pages.total} 页", class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a "下一页", href: next_path, class: "form-secondary"
      end
    end
  end
end
