class Admin::Nodes::DeletePage < AdminLayout
  needs node : Node
  needs nodes : Array(Node)

  def page_title : String
    r(".page_title").t
  end

  def admin_content : Nil
    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      header class: "panel-header" do
        h2 page_title, class: "panel-title"
      end

      div class: "panel-body space-y-6" do
        para r(".description").t(name: node.name), class: "m-0 text-sm text-gray-600"

        if nodes.empty?
          para r(".no_destination_nodes").t, class: "m-0 text-sm text-red-700"
          link r("common.cancel").t, to: Admin::Nodes::Index, class: "form-secondary"
        else
          form_for(
            Admin::Nodes::Delete.with(id: node.id),
            class: "space-y-6",
            hx_push_url: "false"
          ) do
            div class: "form-field" do
              label r(".destination_node").t, for: "destination-node", class: "form-label"

              select_tag(
                id: "destination-node",
                name: "destination_node_id",
                required: "",
                class: "form-input"
              ) do
                option r(".choose_node").t, value: ""

                nodes.each do |destination|
                  option destination.name, value: destination.id.to_s
                end
              end
            end

            div class: "flex flex-wrap gap-3" do
              link r("common.cancel").t, to: Admin::Nodes::Index, class: "form-secondary"
              submit r(".move_and_delete").t, class: "form-submit"
            end
          end
        end
      end
    end
  end
end
