class Forum::NewPage < ForumLayout
  needs operation : SaveTopic

  def page_title
    "发布主题"
  end

  def forum_content
    article class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h1 "发布主题", class: "panel-title"
      end

      form_for Forum::Create, class: "panel-body space-y-6" do
        mount Forum::TopicFields, operation: operation, nodes: nodes, current_user: current_user do
          link "取消", to: Forum::Index, class: "form-secondary"
          submit "发布", class: "form-submit"
        end
      end
    end
  end

  private def show_sidebars? : Bool
    false
  end
end
