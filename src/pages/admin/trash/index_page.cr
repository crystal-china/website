class Admin::Trash::IndexPage < AdminLayout
  needs kind : String
  needs comments : Array(Comment)
  needs topics : Array(Topic)
  needs pages : Lucky::Paginator

  def page_title : String
    r("common.trash").t
  end

  def admin_content : Nil
    header class: "mb-6" do
      h2 r("common.trash").t, class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
      para r(".description").t, class: "mt-1.5 mb-0 text-sm text-gray-600"
    end

    nav class: "mb-5 flex gap-3", "aria-label": r(".categories").t do
      link r("common.comment").t, to: Admin::Trash::Index, class: kind == "comments" ? "form-submit" : "form-secondary"
      link r("common.topic").t, to: Admin::Trash::Index.with(kind: "topics"), class: kind == "topics" ? "form-submit" : "form-secondary"
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
      para r(".no_comments").t, class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        comments.each do |comment|
          article class: "flex flex-wrap items-start justify-between gap-4 px-6 py-4" do
            div class: "min-w-0 flex-1" do
              thread = comment.comment_thread
              source = thread.topic_id ? r(".topic_id").t(id: thread.topic_id.to_s) : r(".doc_id").t(id: thread.doc_id.to_s)

              para class: "m-0 text-xs text-gray-500" do
                text r(".comment_id").t(id: comment.id.to_s)
                mount Shared::UserName, user: comment.user
                text " · #{source}"
              end
              para comment.content[0, 160], class: "mt-1 mb-0 whitespace-pre-wrap break-words text-sm text-gray-800"
              span class: "mt-2 block text-xs text-gray-500" do
                render_deleted_at(comment.soft_deleted_at.not_nil!)
              end
            end

            form_for Admin::Trash::RestoreComment.with(id: comment.id) do
              submit r("common.restore").t, class: "form-secondary"
            end
          end
        end
      end
    end
  end

  private def render_topics : Nil
    if topics.empty?
      para r(".no_topics").t, class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        topics.each do |topic|
          article class: "flex flex-wrap items-start justify-between gap-4 px-6 py-4" do
            div class: "min-w-0 flex-1" do
              h3 topic.title, class: "m-0 text-base font-semibold text-gray-900"
              para class: "mt-1 mb-0 text-xs text-gray-500" do
                text "##{topic.id} · "
                mount Shared::UserName, user: topic.user
                text " · "
                render_deleted_at(topic.soft_deleted_at.not_nil!)
              end
            end

            form_for Admin::Trash::RestoreTopic.with(id: topic.id) do
              submit r("common.restore").t, class: "form-secondary"
            end
          end
        end
      end
    end
  end

  private def render_deleted_at(at : Time) : Nil
    local_time(
      at,
      r(".deleted_at").t(time: time_in_zone(at).to_s("%Y-%m-%d %H:%M:%S %z"))
    )
  end

  private def render_pagination : Nil
    nav class: "mt-6 flex items-center justify-center gap-4 text-sm", "aria-label": r(".pagination").t do
      if (previous_path = pages.path_to_previous)
        a r("common.previous_page").t, href: previous_path, class: "form-secondary"
      end

      span r("common.page_number").t(page: pages.page.to_s, total: pages.total.to_s), class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a r("common.next_page").t, href: next_path, class: "form-secondary"
      end
    end
  end
end
