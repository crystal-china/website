class Forum::EditPage < ForumLayout
  needs topic : Topic
  needs operation : UpdateTopic

  def page_title
    "编辑主题"
  end

  def forum_content
    article class: "app-panel w-full overflow-hidden" do
      header class: "panel-header" do
        h1 "编辑主题", class: "panel-title"
      end

      form_for(
        Forum::Update.with(topic.id),
        class: "panel-body space-y-6",
        script: <<-HYPER
on cancelEditing
  set title_input to the first <input[type="text"]/> in me
  set textarea to the first <textarea/> in me
  set dirty to false

  if title_input.value is not title_input.defaultValue
    set dirty to true
  end

  if textarea.value is not textarea.defaultValue
    set dirty to true
  end

  if dirty
    answer "内容尚未保存，确定放弃修改吗？" with true or false
    if not the result
      exit
    end
  end

  go to url "#{Forum::Show.with(id: topic.id).path}"
end

on keydown[event.key is "Escape"]
  halt the event
  send cancelEditing to me
end
HYPER
      ) do
        mount Forum::TopicFields, operation: operation, nodes: nodes, current_user: current_user do
          button(
            "取消",
            type: "button",
            class: "form-secondary",
            script: "on click send cancelEditing to the closest <form/>"
          )
          submit "保存", class: "form-submit"
        end
      end
    end
  end

  private def show_sidebars? : Bool
    false
  end
end
