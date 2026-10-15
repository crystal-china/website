class Admin::Nodes::EditPage < AdminLayout
  needs node : Node
  needs operation : SaveNode

  def page_title : String
    "编辑节点"
  end

  def admin_content : Nil
    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h2 "编辑节点", class: "panel-title"
        para "修改 #{node.name} 的名称、地址、简介和显示顺序。", class: "panel-description"
      end

      form_for Admin::Nodes::Update.with(id: node.id), class: "panel-body space-y-6" do
        mount Admin::Nodes::Fields, operation: operation, current_user: current_user do
          link "取消", to: Admin::Nodes::Index, class: "form-secondary"
          submit "保存修改", class: "form-submit"
        end
      end
    end
  end
end
