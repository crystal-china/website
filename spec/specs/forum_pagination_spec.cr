require "../spec_helper"

describe "Community pagination" do
  it "returns just the topic list for guest pagination while preserving filters and topic metadata" do
    author = UserFactory.create
    replier = UserFactory.create
    node = SaveNode.create!(name: "分页节点", slug: "forum-pagination", summary: "分页测试", color: "#16a34a", position: 0)
    other_node = SaveNode.create!(name: "其他节点", slug: "other-pagination", summary: "其他节点", color: "#0284c7", position: 0)
    topics = Array.new(21) do |index|
      CreateTopic.create!(user_id: author.id, node_id: node.id, title: "分页主题 #{index}", content: "社区分页正文")
    end
    CreateTopic.create!(user_id: author.id, node_id: other_node.id, title: "其他节点主题", content: "其他节点正文")
    deleted_topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "已删除的分页主题", content: "不应显示")
    DeleteTopic.delete!(deleted_topic)
    thread = CommentThreadQuery.new.topic_id(topics.last.id).first
    CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "最后回复")
    UpdateTopic.update!(topics.last, content: "更新正文以显示编辑时间")

    {"/forum" => 2, "/forum?node=#{node.slug}" => 1}.each do |path, last_page_count|
      response = ApiClient.new.get(path)
      document = XML.parse_html(response.body)
      list = document.xpath_node("//main//section[@id='forum-topics']").not_nil!
      pagination_container = list.xpath_node("./div[nav]").not_nil!
      next_path = pagination_container.xpath_node("./nav/a").not_nil!["href"]

      response.status_code.should eq(200)
      list.xpath_nodes(".//article").size.should eq(20)
      list.content.should contain(replier.nickname)
      list.content.should contain("1 条回复")
      list.content.should contain("编辑于")
      list.content.should_not contain(deleted_topic.title)
      pagination_container["hx-target:inherited"].should eq("#forum-topics")
      pagination_container["hx-swap:inherited"].should eq("outerHTML show:top showTarget:body")
      pagination_container["hx-sync:inherited"].should eq("#forum-topics:replace")
      list["hx-target:inherited"]?.should be_nil
      document.xpath_node("//main//header//a[@href='/forum/new']").should be_nil
      URI.parse(next_path).query_params["node"]?.should eq(URI.parse(path).query_params["node"]?)

      response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
      document = XML.parse_html(response.body)
      list = document.xpath_node("//section[@id='forum-topics']").not_nil!

      response.status_code.should eq(200)
      response.body.should_not contain("<!DOCTYPE")
      document.xpath_node("//main | //header | //footer | //aside").should be_nil
      list.xpath_nodes(".//article").size.should eq(last_page_count)
      list.content.should contain(topics.first.title)
      list.content.should contain("第 2 / 2 页")
      list.content.should_not contain(deleted_topic.title)
      previous_path = list.xpath_node("./div/nav/a").not_nil!["href"]
      URI.parse(previous_path).query_params["page"].should eq("1")
      URI.parse(previous_path).query_params["node"]?.should eq(URI.parse(path).query_params["node"]?)

      {
        ApiClient.new,
        ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true"),
      }.each do |client|
        response = client.get(next_path)
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        response.body.should contain("<!DOCTYPE")
        document.xpath_nodes("//main//section[@id='forum-topics']//article").size.should eq(last_page_count)
        document.xpath_node("//main//aside/nav").should_not be_nil
      end
    end
  end

  it "keeps empty partial responses and both languages working without a page layout" do
    client = ApiClient.new.headers("HX-Request-Type": "partial")

    {"zh-CN", "en"}.each do |locale|
      response = client.get("/forum?locale=#{locale}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//section[@id='forum-topics']/p").should_not be_nil
      document.xpath_node("//main | //header | //footer | //aside | //nav").should be_nil
    end

    author = UserFactory.create
    node = SaveNode.create!(name: "翻译节点", slug: "forum-locale", summary: "翻译测试", color: "#16a34a", position: 0)
    CreateTopic.create!(user_id: author.id, node_id: node.id, title: "公开主题", content: "公开正文")
    response = client.get("/forum?locale=en")

    response.status_code.should eq(200)
    response.body.should contain("0 replies")
    response.body.should contain("Posted")
    response.body.should_not contain("条回复")
  end
end
