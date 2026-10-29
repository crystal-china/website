@[Rosetta::Translatable::Config(prefix: "admin.trash.index_page")]
class Admin::Trash::List < BaseComponent
  needs kind : String
  needs comments : Array(Comment)
  needs topics : Array(Topic)
  needs pages : Lucky::Paginator
  needs focused_comment : Comment? = nil
  needs comment_ids_with_batch_peers : Set(Int64) = Set(Int64).new

  def render : Nil
    section id: "trash-list" do
      if kind == "comments"
        render_comments
      else
        render_topics
      end

      # 分类切换、用户链接和恢复表单不继承分页的局部刷新规则。
      div(
        "hx-target:inherited": "#trash-list",
        "hx-swap:inherited": "outerHTML show:top showTarget:body",
        "hx-sync:inherited": "#trash-list:replace"
      ) do
        mount Shared::Pagination, pages: pages
      end
    end
  end

  private def render_comments : Nil
    if comments.empty?
      para r(".no_comments").t, class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        comments.each do |comment|
          focus = focused_comment
          focused_id = if focus && focus.comment_thread_id == comment.comment_thread_id && focus.soft_deleted_at == comment.soft_deleted_at
                         focus.id
                       end

          mount(
            Admin::Trash::CommentCard,
            comment: comment,
            has_batch_peers: comment_ids_with_batch_peers.includes?(comment.id),
            focused_comment_id: focused_id
          )
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

            div class: "flex items-center gap-3" do
              link(
                r(".preview").t,
                to: Admin::Trash::PreviewTopic.with(id: topic.id),
                class: "form-secondary"
              )

              form_for(
                Admin::Trash::RestoreTopic.with(id: topic.id),
                hx_target: "closest article",
                hx_swap: "delete show:none",
                hx_push_url: "false"
              ) do
                submit r("common.restore").t, class: "form-secondary"
              end
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
end
