class Admin::Nodes::Update < AdminAction
  put "/admin/nodes/:id" do
    node = NodeQuery.find(id)

    SaveNode.update(node, params) do |operation, _updated_node|
      if operation.saved?
        flash.success = r(".node_updated").t

        redirect Admin::Nodes::Index
      else
        build_failed_flash(operation)

        html Admin::Nodes::EditPage, node: node, operation: operation
      end
    end
  end
end
