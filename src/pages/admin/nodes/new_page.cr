class Admin::Nodes::NewPage < AdminLayout
  needs operation : SaveNode

  def page_title : String
    "新增节点"
  end

  def admin_content : Nil
    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h2 "新增节点", class: "panel-title"
        para "新增后即可在社区发布和筛选该节点下的主题。", class: "panel-description"
      end

      form_for Admin::Nodes::Create, class: "panel-body space-y-6" do
        mount Admin::Nodes::Fields, operation: operation, current_user: current_user do
          link "取消", to: Admin::Nodes::Index, class: "form-secondary"
          submit "创建节点", class: "form-submit"
        end
      end
    end
  end
end
