class Forum::EditPage < ForumLayout
  needs topic : Topic
  needs operation : UpdateTopic

  def page_title : String
    r(".page_title").t
  end

  def forum_content : Nil
    article class: "app-panel w-full overflow-hidden" do
      header class: "panel-header" do
        h1 r(".page_title").t, class: "panel-title"
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
    answer #{r("common.discard_changes").t.to_json} with true or false
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
        mount(
          Forum::TopicFields,
          operation: operation,
          nodes: nodes,
          current_user: current_user
        ) do
          button(
            r("common.cancel").t,
            type: "button",
            class: "form-secondary",
            script: "on click send cancelEditing to the closest <form/>"
          )
          submit r("common.save").t, class: "form-submit"
        end
      end
    end
  end

  private def show_sidebars? : Bool
    false
  end
end
