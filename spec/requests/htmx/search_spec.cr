require "../../spec_helper"

describe Htmx::Search do
  it "searches topic titles and content, highlights safely, and excludes deleted topics" do
    user = UserFactory.create
    node = SaveNode.create!(name: "搜索", slug: "search", summary: "测试", color: "#16a34a", position: 0)
    topic = SaveTopic.create!(user_id: user.id, node_id: node.id, title: "Crystal 并发模型", content: "Ruby 通道实践 <img src=x onerror=alert(1)> 与消息传递。")
    deleted_topic = SaveTopic.create!(user_id: user.id, node_id: node.id, title: "Crystal 已删除的主题", content: "Ruby 通道实践")
    DeleteTopic.delete!(deleted_topic)
    client = ApiClient.new

    ["并发模型", "通道实践", "Crystal Ruby"].each do |query|
      path = Htmx::Search.with(scope: "topics", q: query).path
      response = client.get("#{path}&backdoor_user_id=#{user.id}")

      response.status_code.should eq(200)
      response.body.should contain(%(href="#{Forum::Show.with(id: topic.id).path}"))
      response.body.should contain(%(class="keyword"))
      response.body.should_not contain("Crystal 已删除的主题")
      response.body.should_not contain("<img")
    end

    response = client.get("/htmx/search?scope=topics&q=ab&backdoor_user_id=#{user.id}")
    response.status_code.should eq(200)
    response.body.should contain("关键词太短")

    response = client.get("/htmx/search?scope=unknown&q=Crystal&backdoor_user_id=#{user.id}")
    response.status_code.should eq(400)
    ApiClient.new.get("/htmx/search?scope=topics&q=Crystal").status_code.should eq(302)
  end

  it "uses the shared dialog for community pages and preserves document search" do
    user = UserFactory.create
    client = ApiClient.new
    forum = client.get("/forum?backdoor_user_id=#{user.id}")
    docs = client.get("/docs/index?backdoor_user_id=#{user.id}")

    forum.status_code.should eq(200)
    forum.body.should contain("搜索社区")
    forum.body.should contain(%(id="search_dialog"))
    forum.body.should contain(%(hx-get="#{Htmx::Search.with(scope: "topics").path}"))
    forum.body.should contain(%(hx-target="#search-results"))
    docs.status_code.should eq(200)
    docs.body.should contain("搜索文档")
    docs.body.should contain(%(hx-get="#{Htmx::Search.with(scope: "docs").path}"))

    response = client.get("/htmx/search?scope=docs&q=Crystal&backdoor_user_id=#{user.id}")
    response.status_code.should eq(200)
    response.body.should contain(%(href="/docs/index"))

    guest_forum = ApiClient.new.get("/forum")
    guest_forum.body.should_not contain("搜索社区")
    guest_forum.body.should_not contain(%(id="search_dialog"))
  end
end
