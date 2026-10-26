require "../spec_helper"

describe "Forum topic header" do
  it "places icon-only editing controls beside metadata, below the full-width title" do
    author = UserFactory.create
    node = SaveNode.create!(name: "测试", slug: "topic-header", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Channel 关闭后如何让生产者正常退出（补充复现步骤）", content: "正文")

    {"zh-CN" => {"编辑", "删除"}, "en" => {"Edit", "Delete"}}.each do |locale, labels|
      response = ApiClient.new.get("/forum/#{topic.id}?backdoor_user_id=#{author.id}&locale=#{locale}")
      document = XML.parse_html(response.body)
      header = document.xpath_node("//article/header[h1]").not_nil!
      edit = header.xpath_node("./div/div/a[@href='/forum/#{topic.id}/edit']").not_nil!
      delete = header.xpath_node("./div/div/button[@hx-delete='/forum/#{topic.id}']").not_nil!

      response.status_code.should eq(200)
      header.xpath_node("./h1").not_nil!.content.should eq(topic.title)
      header.xpath_node("./div/p/time").should_not be_nil
      edit["title"].should eq(labels[0])
      delete["title"].should eq(labels[1])

      {edit, delete}.each do |control|
        control.content.strip.should be_empty
        control.xpath_node("./img").not_nil!["alt"].should eq(control["title"])
      end

      delete["hx-confirm"].should_not be_empty
      delete["hx-disable"].should eq("this")
    end
  end

  it "keeps follow text for readers and hides editing controls from readers and guests" do
    author = UserFactory.create
    reader = UserFactory.create
    node = SaveNode.create!(name: "测试", slug: "reader-header", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "主题", content: "正文")

    {"", "?backdoor_user_id=#{reader.id}"}.each do |params|
      response = ApiClient.new.get("/forum/#{topic.id}#{params}")
      header = XML.parse_html(response.body).xpath_node("//article/header[h1]").not_nil!

      response.status_code.should eq(200)
      header.xpath_node(".//a[@href='/forum/#{topic.id}/edit']").should be_nil
      header.xpath_node(".//button[@hx-delete='/forum/#{topic.id}']").should be_nil
    end

    response = ApiClient.new.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    follow = XML.parse_html(response.body).xpath_node("//button[@hx-post='/forum/#{topic.id}/follow']").not_nil!

    follow.content.should eq("关注")
  end
end
