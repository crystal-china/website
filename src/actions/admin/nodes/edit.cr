class Admin::Nodes::Edit < AdminAction
  get "/admin/nodes/:id/edit" do
    node = NodeQuery.find(id)

    html(
      Admin::Nodes::EditPage,
      node: node,
      operation: SaveNode.new(node)
    )
  end
end
