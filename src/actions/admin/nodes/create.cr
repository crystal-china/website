class Admin::Nodes::Create < AdminAction
  post "/admin/nodes" do
    SaveNode.create(params) do |operation, node|
      if node
        flash.success = r(".node_created").t
        # 保存成功后重定向到节点列表。

        redirect Admin::Nodes::Index
      else
        # 如果验证失败，强制要求，不可以更新 url
        # 否则，校验失败也会更新地址，因为当前校验失败仍返回 200，htmx 认为 200 就是成功。
        context.response.headers["HX-Push-Url"] = "false"

        build_failed_flash(operation)

        html Admin::Nodes::NewPage, operation: operation
      end
    end
  end
end
