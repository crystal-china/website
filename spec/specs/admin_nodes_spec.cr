require "../spec_helper"

private def follow_node_save_redirect(response : HTTP::Client::Response) : HTTP::Client::Response
  headers = HTTP::Headers.new

  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"]).get(response.headers["Location"])
end

describe "Admin node saves" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "node-actions-admin@example.com"

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "redirects to the freshly sorted node list after creating or updating a node" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")
    original = SaveNode.create!(name: "原有节点", slug: "original-node", summary: "原有简介", color: "#16a34a", position: 1)
    response = client.post(
      "/admin/nodes?backdoor_user_id=#{admin.id}&locale=zh-CN",
      node: {name: "新增节点", slug: "created-node", summary: "新增简介", color: "#0284c7", position: 0}
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/admin/nodes")
    response.headers["HX-Push-Url"]?.should be_nil

    created = NodeQuery.new.slug("created-node").first
    response = follow_node_save_redirect(response)
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//tbody/tr").to_a

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
    rows.map { |row| row.xpath_node("./td[2]").not_nil!.content }.should eq([original.slug, created.slug])
    document.xpath_node("//main//form").should be_nil
    document.xpath_node("//div[contains(@class, 'flash-message--success')]").should_not be_nil

    response = client.put(
      "/admin/nodes/#{created.id}?backdoor_user_id=#{admin.id}&locale=zh-CN",
      node: {name: "更新后的节点", slug: "updated-node", summary: "更新简介", color: "#dc2626", position: 2}
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/admin/nodes")
    response.headers["HX-Push-Url"]?.should be_nil

    response = follow_node_save_redirect(response)
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//tbody/tr").to_a

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
    rows.map { |row| row.xpath_node("./td[2]").not_nil!.content }.should eq(["updated-node", original.slug])
    rows.first.content.should contain("更新后的节点")
    rows.first.content.should contain("更新简介")
    rows.first.xpath_node(".//a[@href='/forum?node=updated-node']").should_not be_nil
    document.xpath_node("//link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/admin/nodes")
    document.xpath_node("//div[@id='page-analytics']").not_nil!["data-page-path"]?.should be_nil
    NodeQuery.find(created.id).name.should eq("更新后的节点")

    refreshed = client.get("/admin/nodes?backdoor_user_id=#{admin.id}&locale=zh-CN")

    refreshed.status_code.should eq(200)
    refreshed.body.should contain("更新后的节点")
    refreshed.body.should_not contain("flash-message--success")
  end

  it "shows topic counts for populated and empty nodes in both locales" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    populated = SaveNode.create!(name: "有主题", slug: "populated-node", summary: "简介", color: "#16a34a", position: 0)
    empty = SaveNode.create!(name: "无主题", slug: "empty-node", summary: "简介", color: "#0284c7", position: 1)

    CreateTopic.create!(
      user_id: admin.id,
      node_id: populated.id,
      title: "测试主题",
      content: "正文"
    )

    {"zh-CN" => "主题数", "en" => "Topics"}.each do |locale, label|
      response = ApiClient.new.get("/admin/nodes?backdoor_user_id=#{admin.id}&locale=#{locale}")
      document = XML.parse_html(response.body)
      headers = document.xpath_nodes("//main//thead/tr/th").to_a
      rows = document.xpath_nodes("//main//tbody/tr").to_a

      response.status_code.should eq(200)
      headers[3].content.should eq(label)
      rows.map { |row| row.xpath_node("./td[2]").not_nil!.content }.should eq([populated.slug, empty.slug])
      rows.map { |row| row.xpath_node("./td[4]").not_nil!.content }.should eq(["1", "0"])
    end
  end

  it "keeps invalid submissions on their forms without changing data or the browser URL" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")
    node = SaveNode.create!(name: "原有节点", slug: "unchanged-node", summary: "原有简介", color: "#16a34a", position: 1)
    attributes = {name: "未保存的节点", slug: "invalid-node", summary: "未保存简介", color: "invalid", position: 0}

    {
      {"post", "/admin/nodes"},
      {"put", "/admin/nodes/#{node.id}"},
    }.each do |method, path|
      request_path = "#{path}?backdoor_user_id=#{admin.id}&locale=zh-CN"
      response = if method == "post"
                   client.post(request_path, node: attributes)
                 else
                   client.put(request_path, node: attributes)
                 end

      document = XML.parse_html(response.body)
      form = document.xpath_node("//main//form").not_nil!

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.headers["HX-Push-Url"].should eq("false")
      form["hx-push-url"]?.should be_nil
      form["action"].should eq(path)
      form.xpath_node(".//input[@name='node:name']").not_nil!["value"].should eq("未保存的节点")
      document.xpath_node("//div[contains(@class, 'flash-message--failure')]").should_not be_nil
      NodeQuery.new.select_count.should eq(1)
      NodeQuery.find(node.id).name.should eq("原有节点")
    end
  end

  it "deletes empty nodes through the confirmed delete button in both locales" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")

    {"zh-CN" => "删除", "en" => "Delete"}.each do |locale, label|
      node = SaveNode.create!(name: "空节点 #{locale}", slug: "delete-empty-#{locale}", summary: "简介", color: "#16a34a", position: 0)
      response = client.get("/admin/nodes?backdoor_user_id=#{admin.id}&locale=#{locale}")
      document = XML.parse_html(response.body)
      button = document.xpath_node("//button[@hx-delete='/admin/nodes/#{node.id}']").not_nil!

      button.content.should eq(label)
      button["hx-confirm"].should_not be_empty
      button["hx-target"].should eq("body")
      button["hx-push-url"].should eq("false")

      response = client.delete("/admin/nodes/#{node.id}?backdoor_user_id=#{admin.id}&locale=#{locale}")

      response.status_code.should eq(303)
      response.headers["Location"].should eq("/admin/nodes")
      NodeQuery.new.id(node.id).none?.should be_true

      response = follow_node_save_redirect(response)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//button[@hx-delete='/admin/nodes/#{node.id}']").should be_nil
      document.xpath_node("//div[contains(@class, 'flash-message--success')]").should_not be_nil
    end
  end

  it "requires a migration destination for nodes with visible or soft-deleted topics" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")
    destination = SaveNode.create!(name: "迁入节点", slug: "migration-destination", summary: "简介", color: "#0284c7", position: 0)

    {false, true}.each do |soft_deleted|
      node = SaveNode.create!(name: "非空节点 #{soft_deleted}", slug: "delete-nonempty-#{soft_deleted}", summary: "简介", color: "#16a34a", position: 0)
      topic = CreateTopic.create!(
        user_id: admin.id,
        node_id: node.id,
        title: "保留的主题",
        content: "正文"
      )

      DeleteTopic.delete!(topic) if soft_deleted

      if soft_deleted
        node.reload.topics_count.should eq(0)
      end

      operation = DeleteNode.new(node)

      operation.delete.should be_false
      operation.errors[:base].should_not be_empty

      response = client.delete("/admin/nodes/#{node.id}?backdoor_user_id=#{admin.id}&locale=zh-CN")

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      NodeQuery.new.id(node.id).any?.should be_true
      TopicQuery.new.with_soft_deleted.id(topic.id).node_id(node.id).any?.should be_true

      document = XML.parse_html(response.body)
      form = document.xpath_node("//main//form").not_nil!
      destination_select = form.xpath_node(".//select[@name='destination_node_id']").not_nil!

      form["action"].should eq("/admin/nodes/#{node.id}")
      destination_select.xpath_node("./option[@value='#{destination.id}']").should_not be_nil
      destination_select.xpath_node("./option[@value='#{node.id}']").should be_nil
      document.xpath_node("//div[contains(@class, 'flash-message--failure')]").not_nil!.content.should contain("节点下仍有主题")
    end
  end

  it "moves all topics and their visible count before deleting a node" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    source = SaveNode.create!(name: "迁出节点", slug: "move-source", summary: "简介", color: "#16a34a", position: 0)
    destination = SaveNode.create!(name: "迁入节点", slug: "move-destination", summary: "简介", color: "#0284c7", position: 1)
    topics = Array.new(3) do |index|
      CreateTopic.create!(
        user_id: admin.id,
        node_id: source.id,
        title: "迁移主题 #{index}",
        content: "保留正文 #{index}"
      )
    end
    topics[-1] = DeleteTopic.delete!(topics.last)
    existing = CreateTopic.create!(user_id: admin.id, node_id: destination.id, title: "原有主题", content: "正文")
    thread = CommentThreadQuery.new.topic_id(topics.first.id).first
    comment = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "保留评论")
    topics[0] = topics.first.reload
    notifications_count = NotificationQuery.new.select_count
    space_count = Space::BaseQuery.find(Space::DEFAULT_ID).topics_count
    user_count = admin.reload.topics_count
    client = ApiClient.new.headers("HX-Request-Type": "full")

    response = client.delete(
      "/admin/nodes/#{source.id}?backdoor_user_id=#{admin.id}&locale=zh-CN",
      destination_node_id: destination.id
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/admin/nodes")
    NodeQuery.new.id(source.id).none?.should be_true
    destination.reload.topics_count.should eq(3)
    TopicQuery.find(existing.id).node_id.should eq(destination.id)
    CommentQuery.find(comment.id).content.should eq("保留评论")
    CommentThreadQuery.find(thread.id).topic_id.should eq(topics.first.id)
    NotificationQuery.new.select_count.should eq(notifications_count)
    Space::BaseQuery.find(Space::DEFAULT_ID).topics_count.should eq(space_count)
    admin.reload.topics_count.should eq(user_count)

    topics.each do |topic|
      moved = TopicQuery.new.with_soft_deleted.id(topic.id).first

      moved.node_id.should eq(destination.id)
      moved.content.should eq(topic.content)
      moved.content_html.should eq(topic.content_html)
      moved.soft_deleted_at.should eq(topic.soft_deleted_at)
      moved.edited_at.should eq(topic.edited_at)
      moved.last_active_at.should eq(topic.last_active_at)
      moved.updated_at.should eq(topic.updated_at)
    end
  end

  it "moves a node containing only soft-deleted topics without increasing the destination count" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    source = SaveNode.create!(name: "回收站节点", slug: "trash-source", summary: "简介", color: "#16a34a", position: 0)
    destination = SaveNode.create!(name: "迁入节点", slug: "trash-destination", summary: "简介", color: "#0284c7", position: 1)
    topic = CreateTopic.create!(user_id: admin.id, node_id: source.id, title: "已删除主题", content: "保留正文")
    topic = DeleteTopic.delete!(topic)

    DeleteNode.delete!(source, destination_node: destination)

    NodeQuery.new.id(source.id).none?.should be_true
    destination.reload.topics_count.should eq(0)
    TopicQuery.new.only_soft_deleted.id(topic.id).first.node_id.should eq(destination.id)
    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    destination.reload.topics_count.should eq(1)
  end

  it "rejects invalid migration destinations without moving or deleting topics" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    source = SaveNode.create!(name: "保留节点", slug: "invalid-migration-source", summary: "简介", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: admin.id, node_id: source.id, title: "保留主题", content: "正文")
    client = ApiClient.new.headers("HX-Request-Type": "full")

    {source.id, Int64::MAX}.each do |destination_id|
      response = client.delete(
        "/admin/nodes/#{source.id}?backdoor_user_id=#{admin.id}&locale=zh-CN",
        destination_node_id: destination_id
      )

      response.status_code.should eq(200)
      response.body.should contain("请选择另一个存在的节点")
      NodeQuery.find(source.id).topics_count.should eq(1)
      TopicQuery.find(topic.id).node_id.should eq(source.id)
    end

    DeleteNode.new(source, destination_node: source).delete.should be_false
    TopicQuery.find(topic.id).node_id.should eq(source.id)
  end

  it "keeps a nonempty node when no migration destination exists" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    source = SaveNode.create!(name: "唯一节点", slug: "only-migration-node", summary: "简介", color: "#16a34a", position: 0)

    CreateTopic.create!(user_id: admin.id, node_id: source.id, title: "保留主题", content: "正文")

    response = ApiClient.new.delete("/admin/nodes/#{source.id}?backdoor_user_id=#{admin.id}&locale=zh-CN")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.body.should contain("请先创建另一个节点")
    document.xpath_node("//main//form").should be_nil
    NodeQuery.new.id(source.id).any?.should be_true
  end

  it "rejects node changes from non-administrators" do
    user = UserFactory.create
    node = SaveNode.create!(name: "原有节点", slug: "protected-node", summary: "原有简介", color: "#16a34a", position: 1)
    client = ApiClient.new.headers("HX-Request-Type": "full")
    attributes = {name: "无权修改", slug: "forbidden-node", summary: "简介", color: "#0284c7", position: 0}

    client.post("/admin/nodes?backdoor_user_id=#{user.id}", node: attributes).status_code.should eq(404)
    client.put("/admin/nodes/#{node.id}?backdoor_user_id=#{user.id}", node: attributes).status_code.should eq(404)
    client.delete("/admin/nodes/#{node.id}?backdoor_user_id=#{user.id}").status_code.should eq(404)
    NodeQuery.new.select_count.should eq(1)
    NodeQuery.find(node.id).name.should eq("原有节点")
  end
end
