class Forum::NewPage < ForumLayout
  needs operation : SaveTopic
  needs nodes : Array(Node)

  def page_title
    "发布主题"
  end

  def content
    section class: "#{page_container_classes} py-10" do
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
  end
end
