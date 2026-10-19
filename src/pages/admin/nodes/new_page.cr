class Admin::Nodes::NewPage < AdminLayout
  needs operation : SaveNode

  def page_title : String
    r("common.new_node").t
  end

  def admin_content : Nil
    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h2 r("common.new_node").t, class: "panel-title"
        para r(".description").t, class: "panel-description"
      end

      form_for Admin::Nodes::Create, class: "panel-body space-y-6" do
        mount(
          Admin::Nodes::Fields,
          operation: operation,
          current_user: current_user
        ) do
          link(
            r("common.cancel").t,
            to: Admin::Nodes::Index,
            class: "form-secondary"
          )
          submit r(".create").t, class: "form-submit"
        end
      end
    end
  end
end
