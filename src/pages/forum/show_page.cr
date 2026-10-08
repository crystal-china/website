class Forum::ShowPage < ForumLayout
  include MarkdownFormatter

  needs topic : Topic
  needs comment_thread : CommentThread
  needs can_delete_topic : Bool

  def page_title
    topic.title
  end

  def content
    time_in_words = TimeInWords::Helpers(TimeInWords::I18n::ZH_CN)

    div class: "#{page_container_classes} py-10" do
      article class: "mx-auto w-full max-w-[90ch]" do
        header class: "border-b border-gray-200 pb-5" do
          div class: "flex items-start gap-4" do
            h1 topic.title, class: "m-0 min-w-0 flex-1 text-3xl font-semibold tracking-tight text-gray-900"

            if (me = current_user)
              div class: "flex shrink-0 items-center gap-2" do
                if me.id == topic.user_id || me.admin?
                  link "编辑", to: Forum::Edit.with(id: topic.id), class: "action-button action-button-neutral h-8"
                end

                if can_delete_topic?
                  button(
                    "删除",
                    type: "button",
                    class: "action-button action-button-danger h-8",
                    hx_delete: Forum::Delete.with(id: topic.id).path,
                    hx_confirm: "删除后，主题及其评论将不可见。确定继续？",
                    hx_disable: "this"
                  )
                end
              end
            end
          end

          para class: "mt-3 mb-0 text-sm text-gray-500" do
            link(
              topic.node.name,
              to: Forum::Index.with(node: topic.node.slug),
              class: "font-medium text-[#145591] no-underline hover:text-[#0f477b] hover:underline"
            )
            text " · #{topic.user.name} "
            span(
              "发布于 #{time_in_words.from(past_time: topic.created_at)}",
              title: topic.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S")
            )

            if (edited_at = topic.edited_at)
              text " · "
              span(
                "编辑于 #{time_in_words.from(past_time: edited_at)}",
                title: edited_at.to_local.to_s("%Y-%m-%d %H:%M:%S")
              )
            end
          end
        end

        div class: "prose prose-neutral my-8 max-w-none text-base leading-7 text-gray-900" do
          raw user_markdown(topic.content)
        end

        section id: "form_with_comments", class: "mt-10" do
          mount(
            Comments::Form,
            current_user: current_user,
            comment_thread_id: comment_thread.id
          )

          show_comments_when_revealed(comment_thread.id)
        end
      end

      mount Comments::Dialog
    end
  end
end
