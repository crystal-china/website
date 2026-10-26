require "../spec_helper"

describe "Topic controls after commenting" do
  it "removes the author's delete button without replacing the topic or redirecting" do
    author = UserFactory.create
    node = SaveNode.create!(name: "主题操作", slug: "topic-controls", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "主题操作", content: "主题正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    client = ApiClient.new
    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{author.id}")
    controls_path = "//div[@id='topic-#{topic.id}-controls']"
    delete_path = "//button[@hx-delete='/forum/#{topic.id}']"

    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_node("#{controls_path}#{delete_path}").should_not be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post(
        "/htmx/comments?backdoor_user_id=#{author.id}",
        comment_thread_id: thread.id,
        content: "第一条评论"
      )
      document = XML.parse_html(response.body)
      partial_path = "//hx-partial[@hx-target='#topic-#{topic.id}-controls'][@hx-swap='outerHTML']"

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      document.xpath_node("//div[@id='comments']").should_not be_nil
      document.xpath_node("#{partial_path}#{controls_path}").should_not be_nil
      document.xpath_node("#{partial_path}//a[@href='/forum/#{topic.id}/edit']").should_not be_nil
      document.xpath_node(delete_path).should be_nil
      document.xpath_node("//h1").should be_nil
      client.delete("/forum/#{topic.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
    end
  end

  it "keeps administrators' delete permission and does not update topic controls for document comments" do
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "topic-controls-admin@example.com"
    admin = UserFactory.create &.email("topic-controls-admin@example.com")
    node = SaveNode.create!(name: "管理员主题操作", slug: "admin-topic-controls", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: admin.id, node_id: node.id, title: "管理员主题", content: "正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    doc = SaveDoc.create!(path_index: "/docs/topic-controls", content: "文档正文")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post(
        "/htmx/comments?backdoor_user_id=#{admin.id}",
        comment_thread_id: thread.id,
        content: "管理员评论"
      )
      partial_path = "//hx-partial[@hx-target='#topic-#{topic.id}-controls']"

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("#{partial_path}//button[@hx-delete='/forum/#{topic.id}']").should_not be_nil

      response = client.post(
        "/htmx/comments?backdoor_user_id=#{admin.id}",
        comment_thread_id: doc_thread.id,
        content: "文档评论"
      )
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//div[@id='comments']").should_not be_nil
      document.xpath_node("//hx-partial[starts-with(@hx-target, '#topic-')]").should be_nil
    end
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end
end
