require "../spec_helper"

private def seed_deleted_trash(user : User, kind : String) : Array(Int64)
  if kind == "comments"
    doc = SaveDoc.create!(path_index: "/docs/trash-pagination", content: "回收站分页测试")
    thread = CommentThreadQuery.new.doc_id(doc.id).first

    Array.new(21) do |index|
      comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "回收站评论 #{index}")
      DeleteComment.delete!(comment, actor_id: user.id)
      comment.id
    end
  else
    node = SaveNode.create!(name: "回收站测试", slug: "trash-pagination", summary: "分页测试", color: "#16a34a", position: 0)

    Array.new(21) do |index|
      topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "回收站主题 #{index}", content: "回收站分页正文")
      DeleteTopic.delete!(topic, actor_id: user.id)
      topic.id
    end
  end
end

describe "Trash pagination" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "trash-pagination-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  {"comments", "topics"}.each do |kind|
    it "paginates #{kind} locally while keeping direct visits and restores as full pages" do
      admin = UserFactory.create &.email("trash-pagination-admin@example.com")
      ids = seed_deleted_trash(admin, kind)
      response = ApiClient.new.get("/admin/trash?kind=#{kind}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)
      list = document.xpath_node("//main//section[@id='trash-list']").not_nil!
      pagination_container = list.xpath_node("./div[nav]").not_nil!
      next_path = pagination_container.xpath_node("./nav/a").not_nil!["href"]

      response.status_code.should eq(200)
      list.xpath_nodes(".//article").size.should eq(20)
      pagination_container["hx-target:inherited"].should eq("#trash-list")
      pagination_container["hx-swap:inherited"].should eq("outerHTML show:top showTarget:body")
      pagination_container["hx-sync:inherited"].should eq("#trash-list:replace")
      list["hx-target:inherited"]?.should be_nil
      URI.parse(next_path).query_params["kind"].should eq(kind)

      partial_client = ApiClient.new.headers("HX-Request-Type": "partial")
      response = partial_client.get(next_path)
      document = XML.parse_html(response.body)
      list = document.xpath_node("//section[@id='trash-list']").not_nil!
      restore_path = "/admin/trash/#{kind}/#{ids.first}/restore"

      response.status_code.should eq(200)
      response.body.should_not contain("<!DOCTYPE")
      document.xpath_node("//main | //header | //footer").should be_nil
      list.xpath_nodes(".//article").size.should eq(1)
      list.content.should contain("第 2 / 2 页")
      list.xpath_node(".//form[@action='#{restore_path}']").should_not be_nil
      previous_path = list.xpath_node("./div/nav/a").not_nil!["href"]
      URI.parse(previous_path).query_params["kind"].should eq(kind)
      URI.parse(previous_path).query_params["page"].should eq("1")

      {
        ApiClient.new,
        ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true"),
      }.each do |client|
        response = client.get(next_path)

        response.status_code.should eq(200)
        response.body.should contain("<!DOCTYPE")
        XML.parse_html(response.body).xpath_node("//main//section[@id='trash-list']").should_not be_nil
      end

      Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
        response = ApiClient.new.post("#{restore_path}?backdoor_user_id=#{admin.id}")
        redirect_path = response.headers["Location"]
        headers = HTTP::Headers.new
        HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

        response.status_code.should eq(303)
        URI.parse(redirect_path).path.should eq("/admin/trash")
        URI.parse(redirect_path).query_params["page"]?.should be_nil
        URI.parse(redirect_path).query_params["kind"]?.should eq(kind == "topics" ? "topics" : nil)

        separator = redirect_path.includes?('?') ? '&' : '?'
        response = ApiClient.new.headers(Cookie: headers["Cookie"]).get("#{redirect_path}#{separator}backdoor_user_id=#{admin.id}")
        document = XML.parse_html(response.body)
        list = document.xpath_node("//main//section[@id='trash-list']").not_nil!

        response.status_code.should eq(200)
        response.body.should contain("<!DOCTYPE")
        list.xpath_nodes(".//article").size.should eq(20)
        list.xpath_node(".//form[@action='#{restore_path}']").should be_nil
        list.xpath_node(".//nav").should be_nil
        document.xpath_node("//*[contains(@class, 'flash-message--success')]").should_not be_nil
      end
    end
  end

  it "returns an empty list component without exposing full-page controls or bypassing permissions" do
    admin = UserFactory.create &.email("trash-pagination-admin@example.com")
    user = UserFactory.create
    client = ApiClient.new.headers("HX-Request-Type": "partial")

    {"comments", "topics"}.each do |kind|
      response = client.get("/admin/trash?kind=#{kind}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//section[@id='trash-list']").should_not be_nil
      document.xpath_node("//main | //header | //footer | //nav | //form").should be_nil
      client.get("/admin/trash?kind=#{kind}&backdoor_user_id=#{user.id}").status_code.should eq(404)
    end

    client.get("/admin/trash?kind=invalid&backdoor_user_id=#{admin.id}").status_code.should eq(400)
    client.get("/admin/trash").status_code.should eq(401)
  end
end
