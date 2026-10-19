class Forum::NewPage < ForumLayout
  needs operation : CreateTopic

  def page_title : String
    r("common.new_topic").t
  end

  def forum_content : Nil
    article class: "app-panel w-full overflow-hidden" do
      header class: "panel-header" do
        h1 r("common.new_topic").t, class: "panel-title"
      end

      form_for Forum::Create, class: "panel-body space-y-6" do
        mount(
          Forum::TopicFields,
          operation: operation,
          nodes: nodes,
          current_user: current_user
        ) do
          link(
            r("common.cancel").t,
            to: Forum::Index,
            class: "form-secondary"
          )
          submit r(".publish").t, class: "form-submit"
        end
      end
    end
  end

  private def show_sidebars? : Bool
    false
  end
end
