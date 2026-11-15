class Admin::Nodes::Delete < AdminAction
  param destination_node_id : Int64?

  delete "/admin/nodes/:id" do
    node = NodeQuery.find(id)
    destination : Node? = nil

    if (destination_id = destination_node_id)
      destination = NodeQuery.new.id(destination_id).first?

      if destination.nil?
        flash.failure = r("validations.node_destination_invalid").t

        return render_migration_page(node)
      end
    end

    DeleteNode.delete(node, destination_node: destination) do |operation, _deleted_node|
      if operation.deleted?
        flash.success = r(".node_deleted").t

        redirect Admin::Nodes::Index
      else
        flash.failure = operation.errors.values.flatten.join("\n")

        render_migration_page(node)
      end
    end
  end

  private def render_migration_page(node : Node) : Lucky::Response
    html(
      Admin::Nodes::DeletePage,
      node: node,
      nodes: NodeQuery.new.sorted.results.reject { |candidate| candidate.id == node.id }
    )
  end
end
