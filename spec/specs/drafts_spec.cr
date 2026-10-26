require "../spec_helper"

private def drafts_client(user : User) : ApiClient
  response = ApiClient.new.post("/sign_in", user: {login: user.login_name, password: "password"})
  headers = HTTP::Headers.new
  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"])
end

describe "Local editor drafts" do
  around_each do |example|
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  end

  it "marks only topic and comment fields with stable user-specific draft keys" do
    user = UserFactory.create
    node = SaveNode.create!(name: "草稿节点", slug: "drafts", summary: "草稿测试", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "草稿主题", content: "已保存正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "已保存评论")
    client = drafts_client(user)

    {
      "/forum/new"                          => "#{user.id}:topic:new",
      "/forum/#{topic.id}/edit"             => "#{user.id}:topic:#{topic.id}:edit",
      "/forum/#{topic.id}"                  => "#{user.id}:thread:#{thread.id}",
      "/htmx/comments/new?id=#{comment.id}" => "#{user.id}:reply:#{comment.id}",
      "/htmx/comments/edit/#{comment.id}"   => "#{user.id}:comment:#{comment.id}:edit",
    }.each do |path, key|
      response = client.get(path)
      document = XML.parse_html(response.body)
      containers = document.xpath_nodes("//*[@data-draft-key]")

      response.status_code.should eq(200)
      containers.size.should eq(1)
      containers.first["data-draft-key"].should eq(key)
      fields = containers.first.xpath_nodes(".//*[@data-draft-field]")
      fields.map(&.["name"]).sort!.should eq(path.ends_with?("/new") || path.ends_with?("/edit") ? ["content", "topic:node_id", "topic:title"] : ["content"])
      fields.each(&.["id"].should_not(be_empty))

      if path == "/forum/new" || path == "/forum/#{topic.id}/edit"
        containers.first["hx-push-url"].should eq("false")
      end
    end

    XML.parse_html(ApiClient.new.get("/forum/#{topic.id}").body).xpath_nodes("//*[@data-draft-key]").should be_empty
    XML.parse_html(client.get("/users/#{user.id}/edit").body).xpath_nodes("//*[@data-draft-key]").should be_empty
  end

  it "renders saved topics directly for HTMX submissions but keeps ordinary redirects" do
    user = UserFactory.create
    node = SaveNode.create!(name: "提交节点", slug: "draft-save", summary: "提交测试", color: "#0284c7", position: 0)
    client = drafts_client(user)
    response = client.post("/forum", topic: {title: "普通提交", node_id: node.id}, content: "普通正文")

    response.status_code.should eq(303)
    response.headers["X-Draft-Saved"]?.should be_nil

    client.headers("HX-Request-Type": "full")
    response = client.post("/forum", topic: {title: "草稿提交", node_id: node.id}, content: "草稿正文")
    topic = TopicQuery.new.title("草稿提交").first

    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")
    response.headers["HX-Push-Url"].should eq("/forum/#{topic.id}")
    response.headers["HX-Location"]?.should be_nil
    response.headers["Location"]?.should be_nil
    document = XML.parse_html(response.body)

    response.body.should contain("<!DOCTYPE")
    document.xpath_node("//main//h1").not_nil!.content.should eq("草稿提交")
    document.xpath_node("//head/title").not_nil!.content.should contain("草稿提交")
    document.xpath_node("//link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/forum/#{topic.id}")
    document.xpath_node("//meta[@property='og:url']").not_nil!["content"].should eq("#{Lucky::RouteHelper.settings.base_uri}/forum/#{topic.id}")
    document.xpath_node("//main//aside/nav").should_not be_nil
    document.xpath_node("//section[@id='form_with_comments']").should_not be_nil
    response.body.should contain("草稿正文")
    response.body.should contain("/forum/#{topic.id}/edit")

    moved_node = SaveNode.create!(name: "移动后的节点", slug: "draft-save-moved", summary: "移动测试", color: "#16a34a", position: 0)
    response = client.put("/forum/#{topic.id}", topic: {title: "修改标题", node_id: moved_node.id}, content: "修改正文")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")
    response.headers["HX-Push-Url"].should eq("/forum/#{topic.id}")
    response.headers["HX-Location"]?.should be_nil
    document = XML.parse_html(response.body)

    document.xpath_node("//main//h1").not_nil!.content.should eq("修改标题")
    document.xpath_node("//head/title").not_nil!.content.should contain("修改标题")
    document.xpath_node("//main//article/header/div/p/a[@href='/forum?node=#{moved_node.slug}']").not_nil!.content.should eq(moved_node.name)
    response.body.should contain("修改正文")
    response.body.should_not contain("草稿正文")
    message = Rosetta.find("forum.update.topic_updated").t
    response.body.should contain(message)

    cookies = HTTP::Cookies.from_server_headers(response.headers)
    session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
    JSON.parse(session.get?(Lucky::FlashStore::SESSION_KEY) || "{}").as_h.has_key?("success").should be_false

    headers = HTTP::Headers.new
    cookies.add_request_headers(headers)
    refreshed = ApiClient.new.headers(Cookie: headers["Cookie"]).get("/forum/#{topic.id}")
    refreshed.status_code.should eq(200)
    refreshed.body.should_not contain(message)
    XML.parse_html(refreshed.body).xpath_node("//main//h1").not_nil!.content.should eq("修改标题")

    guest = ApiClient.new.get("/forum/#{topic.id}")
    guest.status_code.should eq(200)
    XML.parse_html(guest.body).xpath_node("//main//h1").not_nil!.content.should eq("修改标题")
    guest.body.should_not contain("/forum/#{topic.id}/edit")
    guest.headers["X-Draft-Saved"]?.should be_nil

    response = client.post("/forum", topic: {title: "", node_id: node.id}, content: "")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"]?.should be_nil
    response.headers["HX-Location"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
    response = client.put("/forum/#{topic.id}", topic: {title: "修改标题", node_id: moved_node.id}, content: "")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
  end

  it "submits comments through forms while keeping preview and cancellation separate" do
    user = UserFactory.create
    node = SaveNode.create!(name: "表单节点", slug: "comment-forms", summary: "表单测试", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "评论表单", content: "主题正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "子评论")
    client = drafts_client(user)

    {
      "/forum/#{topic.id}"                             => {"tab", "#comments", {comment_thread_id: thread.id}.to_json},
      "/htmx/comments/new?id=#{child.id}&order_by=asc" => {"comment", "#comment-#{root.id}-replies", {id: child.id, op: "new"}.to_json},
      "/htmx/comments/edit/#{root.id}?order_by=desc"   => {"comment", "#comment-#{root.id}-content", {id: root.id, op: "edit"}.to_json},
    }.each do |path, (html_id, target, values)|
      document = XML.parse_html(client.get(path).body)
      form = document.xpath_node("//form[@id='#{html_id}-form']").not_nil!

      document.xpath_nodes("//*[@id='#{html_id}-form']").size.should eq(1)
      form.xpath_nodes(".//form").should be_empty
      form["action"].should eq("/htmx/comments")
      form["method"].should eq("post")
      form["hx-post"].should eq("/htmx/comments")
      form["hx-target"].should eq(target)
      form["hx-swap"].should eq("outerHTML")
      form["hx-push-url"].should eq("false")
      form["hx-disable"].should eq("find button[type=submit]")
      JSON.parse(form["hx-vals"]).should eq(JSON.parse(values))
      form.xpath_node(".//textarea[@name='content']").should_not be_nil
      form.xpath_node(".//input[@name='_csrf']").should_not be_nil
      form.xpath_node(".//button[@type='submit']").should_not be_nil
      form.xpath_nodes(".//button[@hx-post]").should be_empty
      form.xpath_node(".//input[@hx-put='/htmx/docs/markdown_render']").should_not be_nil
      form["script"].should contain("ctx.sourceElement is me")

      if html_id == "tab"
        form["hx-include"].should eq("#comments-order-by")
        form.xpath_node(".//input[@name='order_by']").should be_nil
      else
        form["hx-include"]?.should be_nil
        form.xpath_node(".//input[@name='order_by']").not_nil!["value"].should eq(path.ends_with?("asc") ? "asc" : "desc")
        form.xpath_node(".//button[@type='button']").should_not be_nil
      end
    end

    guest = XML.parse_html(ApiClient.new.get("/forum/#{topic.id}").body)
    guest.xpath_node("//form[@id='tab-form']//button[@type='submit'][@disabled]").should_not be_nil
    guest.xpath_nodes("//*[@data-draft-key]").should be_empty
    guest.xpath_node("//dialog[@id='comment-dialog']/form[@id='comment-form']").should_not be_nil
    guest.xpath_nodes("//form//form").should be_empty
    Comments::Dialog.comment_form_target.should eq("form#comment-form")
  end

  it "confirms root replies, child replies and comment edits but not rejected or preview requests" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/draft-test", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    client = drafts_client(user)
    response = client.post("/htmx/comments", comment_thread_id: thread.id, content: "顶级评论")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")
    comment = CommentQuery.new.comment_thread_id(thread.id).first

    response = client.post("/htmx/comments", id: comment.id, op: "new", content: "子评论")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")
    response = client.post("/htmx/comments", id: comment.id, op: "edit", content: "编辑评论")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")

    response = client.post("/htmx/comments", comment_thread_id: thread.id, content: "")
    response.status_code.should eq(400)
    response.headers["X-Draft-Saved"]?.should be_nil
    response = client.put("/htmx/docs/markdown_render", content: "仅预览")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"]?.should be_nil
  end
end
