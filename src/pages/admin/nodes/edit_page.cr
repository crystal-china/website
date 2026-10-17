class Admin::Nodes::EditPage < AdminLayout
  needs node : Node
  needs operation : SaveNode

  def page_title : String
    r(".page_title").t
  end

  def admin_content : Nil
    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h2 r(".page_title").t, class: "panel-title"
        para r(".description").t(name: node.name), class: "panel-description"
      end

      form_for Admin::Nodes::Update.with(id: node.id), class: "panel-body space-y-6" do
        mount Admin::Nodes::Fields, operation: operation, current_user: current_user do
          link r("common.cancel").t, to: Admin::Nodes::Index, class: "form-secondary"
          submit r("common.save_changes").t, class: "form-submit"
        end
      end
    end
  end
end
