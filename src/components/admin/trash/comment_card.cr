@[Rosetta::Translatable::Config(prefix: "admin.trash.index_page")]
class Admin::Trash::CommentCard < BaseComponent
  needs comment : Comment
  needs has_batch_peers : Bool = false
  needs focused_comment_id : Int64? = nil
  needs nested : Bool = false

  def render : Nil
    if nested?
      render_card
    else
      # 卡片与展开列表互为兄弟节点，恢复入口评论时不会移走其他待恢复评论。
      div(
        id: "trash-comment-#{comment.id}-group",
        class: "trash-comment-group comment-root px-4 py-4 sm:px-6"
      ) do
        render_card

        # 同批记录只展示第二层，不再生成展开入口，避免相同批次递归套娃。
        render_batch_toggle if has_batch_peers?
      end
    end
  end

  private def render_card : Nil
    options = {} of String => String
    classes = nested? ? "px-3 py-3 sm:px-4" : "comment-body"
    remove_restored_comment_and_empty_batch_script = <<-HYPER
on trash:comment:restored(batch_empty)
  set batchGroup to closest .trash-comment-group
  remove closest <article/>
  if batch_empty
    remove batchGroup
  end
end
HYPER

    if focused_comment_id == comment.id
      scroll_to_located_deleted_comment_script = <<-HYPER
init
  wait a tick
  scroll to the middle of me
end
HYPER

      options["script"] = scroll_to_located_deleted_comment_script
      classes += " bg-amber-50 ring-2 ring-inset ring-amber-300"
    end

    article(options, id: html_id, class: classes) do
      div(
        id: "#{html_id}-content",
        class: "flex flex-wrap items-start justify-between gap-4"
      ) do
        render_content

        form_for(
          Admin::Trash::RestoreComment.with(id: comment.id),
          script: remove_restored_comment_and_empty_batch_script
        ) do
          submit r("common.restore").t, class: "form-secondary"
        end
      end
    end
  end

  private def render_content : Nil
    thread = comment.comment_thread
    source = thread.topic_id ? r(".topic_id").t(id: thread.topic_id.to_s) : r(".doc_id").t(id: thread.doc_id.to_s)

    div class: "min-w-0 flex-1" do
      para class: "m-0 text-xs text-gray-500" do
        text r(".comment_id").t(id: comment.id.to_s)
        mount Shared::UserName, user: comment.user
        text " · #{source}"
      end

      para comment.content[0, 160], class: "mt-1 mb-0 text-sm break-words whitespace-pre-wrap text-gray-800"

      span class: "mt-2 block text-xs text-gray-500" do
        local_time(
          comment.soft_deleted_at.not_nil!,
          r(".deleted_at").t(time: time_in_zone(comment.soft_deleted_at.not_nil!).to_s("%Y-%m-%d %H:%M:%S %z"))
        )

        if (parent = comment.parent)
          if parent.soft_deleted? && parent.soft_deleted_at != comment.soft_deleted_at
            text " · "
            link(
              r(".parent_comment").t(id: parent.id.to_s),
              to: Admin::Trash::ShowComment.with(id: parent.id),
              class: "text-sky-700 hover:underline"
            )
          end
        end
      end
    end
  end

  private def render_batch_toggle : Nil
    focus_id = focused_comment_id == comment.id ? nil : focused_comment_id
    show_collapse_button_after_loading_batch = htmx_success <<-HYPER
add @hidden to me
remove @hidden from the next <button/>
HYPER
    clear_batch_and_show_expand_button = <<-HYPER
on click
  put "" into ##{html_id}-replies-list
  add @hidden to me
  remove @hidden from the previous <button/>
end
HYPER

    div class: "comment-replies" do
      div class: "comment-replies-toggle" do
        button(
          type: "button",
          class: "comment-replies-expand",
          hx_get: Admin::Trash::BatchComments.with(
            id: comment.id,
            deleted_at: comment.soft_deleted_at.not_nil!.to_rfc3339(fraction_digits: 6),
            comment_id: focus_id
          ).path,
          hx_target: "##{html_id}-replies-list",
          hx_swap: "outerHTML show:none",
          hx_push_url: "false",
          hx_trigger: focus_id ? "load, click" : "click",
          script: show_collapse_button_after_loading_batch
        ) do
          span class: "comment-replies-icon"
          span r(".view_deletion_batch").t
          mount Shared::Spinner, text: r("common.loading_comments").t, width: "10px"
        end

        button(
          type: "button",
          attrs: [:hidden],
          class: "comment-replies-collapse",
          script: clear_batch_and_show_expand_button
        ) do
          span class: "comment-replies-icon"
          span r(".collapse_deletion_batch").t
        end
      end

      div id: "#{html_id}-replies-list"
    end
  end

  private def html_id : String
    "trash-comment-#{comment.id}"
  end
end
