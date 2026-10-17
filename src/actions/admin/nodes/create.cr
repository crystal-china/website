class Admin::Nodes::Create < AdminAction
  post "/admin/nodes" do
    SaveNode.create(params) do |operation, node|
      if node
        flash.success = r(".node_created").t

        redirect Admin::Nodes::Index
      else
        build_failed_flash(operation)

        html Admin::Nodes::NewPage, operation: operation
      end
    end
  end
end
