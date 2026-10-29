require "../spec_helper"

private def followed_topics_node : Node
  SaveNode.create!(name: "关注列表测试", slug: "followed-topics", summary: "测试", color: "#16a34a", position: 0)
end

describe "Followed topics list" do
  it "requires login for following and only shows the header filter to signed-in users" do
    user = UserFactory.create
    client = ApiClient.new
    response = client.get("/forum?following=true")

    response.status_code.should eq(303)
    response.headers["Location"].should eq(SignIns::New.path)
    client.headers("HX-Request-Type": "partial").get("/forum?following=true").status_code.should eq(401)

    response = ApiClient.new.get("/forum")
    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_node("//main//header//div[@class='segmented-control']").should be_nil
    ApiClient.new.get("/forum?following=false").status_code.should eq(200)

    response = ApiClient.new.get("/forum?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    entry = document.xpath_node("//main//header//div[@class='segmented-control']/a[@href='/forum?following=true']").not_nil!

    entry.content.should eq("仅关注")
    entry["class"].should_not contain("segmented-option-active")
    document.xpath_node("//main//header//div[@class='segmented-control']/a[@href='/forum']").not_nil!["class"].should contain("segmented-option-active")
    document.xpath_node("//main//aside//a[@href='/forum?following=true']").should be_nil
    document.xpath_node("//main//aside//a[@href='/forum']").not_nil!["class"].should contain("bg-gray-900")
  end

  it "lists only the current account's explicitly followed topics and selects the following filter" do
    author = UserFactory.create
    user = UserFactory.create
    other = UserFactory.create
    node = followed_topics_node
    followed = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "我关注的讨论", content: "正文")
    others_topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "别人关注的讨论", content: "正文")
    own_topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "自己发布但没有关注", content: "正文")
    SaveTopicFollow.create!(topic_id: followed.id, follower_id: user.id)
    SaveTopicFollow.create!(topic_id: followed.id, follower_id: other.id)
    SaveTopicFollow.create!(topic_id: others_topic.id, follower_id: other.id)
    response = ApiClient.new.get("/forum?following=true&backdoor_user_id=#{user.id}&user_id=#{other.id}")
    document = XML.parse_html(response.body)
    list = document.xpath_node("//section[@id='forum-topics']").not_nil!

    response.status_code.should eq(200)
    document.xpath_node("//main//h1").not_nil!.content.should eq("社区")
    list.xpath_nodes(".//article").size.should eq(1)
    list.content.should contain(followed.title)
    list.content.should_not contain(others_topic.title)
    list.content.should_not contain(own_topic.title)
    document.xpath_nodes("//main//aside//a[contains(@class, 'bg-gray-900')]").map(&.["href"]).should eq(["/forum?following=true"])
    document.xpath_node("//main//header//div[@class='segmented-control']/a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("仅关注")
    document.xpath_node("//main//header//a[@href='/forum/new']").should_not be_nil
  end

  it "combines node and following filters, preserving each when switching the other" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    other_node = SaveNode.create!(name: "其他节点", slug: "other-followed", summary: "其他测试", color: "#0284c7", position: 0)
    followed = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "节点内已关注", content: "正文")
    unfollowed = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "节点内未关注", content: "正文")
    outside = CreateTopic.create!(user_id: author.id, node_id: other_node.id, title: "节点外已关注", content: "正文")
    [followed, outside].each do |topic|
      SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
    end
    response = ApiClient.new.get("/forum?node=#{node.slug}&following=true&backdoor_user_id=#{user.id}&page=2")
    document = XML.parse_html(response.body)
    filter = document.xpath_node("//main//header//div[@class='segmented-control']").not_nil!
    all_path = filter.xpath_node("./a[1]").not_nil!["href"]
    following_path = filter.xpath_node("./a[2]").not_nil!["href"]
    active_node = document.xpath_node("//main//aside//a[contains(@class, 'bg-gray-900')]").not_nil!
    other_node_path = document.xpath_nodes("//main//aside//a").find!(&.content.includes?(other_node.name))["href"]

    response.status_code.should eq(200)
    document.xpath_node("//main//h1").not_nil!.content.should eq(node.name)
    active_node.content.should contain(node.name)
    URI.parse(all_path).query_params["node"].should eq(node.slug)
    URI.parse(all_path).query_params["following"]?.should be_nil
    URI.parse(following_path).query_params["node"].should eq(node.slug)
    URI.parse(following_path).query_params["following"].should eq("true")
    [all_path, following_path, other_node_path].each do |path|
      URI.parse(path).query_params["page"]?.should be_nil
    end
    URI.parse(other_node_path).query_params["following"].should eq("true")

    response = ApiClient.new.get("#{following_path}&backdoor_user_id=#{user.id}")
    list = XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!
    list.xpath_nodes(".//article").size.should eq(1)
    list.content.should contain(followed.title)
    list.content.should_not contain(unfollowed.title)
    list.content.should_not contain(outside.title)
    node_path = list.xpath_node(".//article//p/a").not_nil!["href"]
    URI.parse(node_path).query_params["following"].should eq("true")

    response = ApiClient.new.get("#{other_node_path}&backdoor_user_id=#{user.id}")
    list = XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!
    list.content.should contain(outside.title)
    list.content.should_not contain(followed.title)

    response = ApiClient.new.get("#{all_path}&backdoor_user_id=#{user.id}")
    list = XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!
    list.xpath_nodes(".//article").size.should eq(2)
    list.content.should contain(followed.title)
    list.content.should contain(unfollowed.title)
    list.content.should_not contain(outside.title)
  end

  it "orders followed topics by the latest reply and preloads the usual topic metadata" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    older = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "旧主题有新回复", content: "正文")
    newer = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "较新的主题", content: "正文")
    [older, newer].each do |topic|
      SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
    end
    thread = CommentThreadQuery.new.topic_id(older.id).first
    CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "推动主题活跃时间", created_at: newer.created_at + 1.minute)
    response = ApiClient.new.get("/forum?following=true&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    articles = document.xpath_nodes("//section[@id='forum-topics']//article")

    response.status_code.should eq(200)
    articles.map(&.xpath_node(".//h2/a").not_nil!.content).should eq([older.title, newer.title])
    articles.first.content.should contain("1 条回复")
    articles.first.content.should contain(user.nickname)
    articles.first.content.should contain(author.nickname)
  end

  it "preserves the following filter through topic details and back to the node list" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "保留浏览筛选", content: "正文")
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
    response = ApiClient.new.get("/forum?node=#{node.slug}&following=true&backdoor_user_id=#{user.id}")
    list = XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!
    topic_path = list.xpath_node(".//h2/a").not_nil!["href"]

    URI.parse(topic_path).path.should eq("/forum/#{topic.id}")
    URI.parse(topic_path).query_params["following"].should eq("true")
    response = ApiClient.new.get("#{topic_path}&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    sidebar_links = document.xpath_nodes("//main//aside/nav//a")
    node_path = sidebar_links.find!(&.content.includes?(node.name))["href"]

    response.status_code.should eq(200)
    sidebar_links.each do |link|
      URI.parse(link["href"]).query_params["following"].should eq("true")
    end
    metadata_node_path = document.xpath_node("//main//article/header/div/p/a").not_nil!["href"]
    URI.parse(metadata_node_path).query_params["following"].should eq("true")
    response = ApiClient.new.get("#{node_path}&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main//h1").not_nil!.content.should eq(node.name)
    document.xpath_node("//main//header//div[@class='segmented-control']/a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("仅关注")
    document.xpath_node("//section[@id='forum-topics']").not_nil!.content.should contain(topic.title)
  end

  it "keeps the browsing filter independent of subscription state, public access and the canonical URL" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "筛选不等于关注", content: "正文")
    path = "/forum/#{topic.id}"
    response = ApiClient.new.get("#{path}?following=true&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//button[@hx-post='#{path}/follow']").should_not be_nil
    TopicFollowQuery.new.any?.should be_false
    canonical = URI.parse(document.xpath_node("//link[@rel='canonical']").not_nil!["href"])
    canonical.path.should eq(path)
    canonical.query.should be_nil
    ApiClient.new.get("#{path}?following=true").status_code.should eq(200)

    SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
    response = ApiClient.new.get("#{path}?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//button[@hx-delete='#{path}/follow']").should_not be_nil
    document.xpath_nodes("//main//aside/nav//a").each do |link|
      URI.parse(link["href"]).query_params["following"]?.should be_nil
    end
    response = ApiClient.new.get("/forum?backdoor_user_id=#{user.id}")
    topic_path = XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']//h2/a").not_nil!["href"]
    URI.parse(topic_path).query_params["following"]?.should be_nil
  end

  it "preserves both filters while paginating and supports full-page history restoration" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    topics = Array.new(21) do |index|
      topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "关注分页 #{index}", content: "正文")
      SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
      topic
    end
    CreateTopic.create!(user_id: author.id, node_id: node.id, title: "未关注的主题", content: "正文")
    other_node = SaveNode.create!(name: "分页外节点", slug: "outside-followed-page", summary: "其他测试", color: "#0284c7", position: 0)
    outside = CreateTopic.create!(user_id: author.id, node_id: other_node.id, title: "节点外的关注主题", content: "正文")
    SaveTopicFollow.create!(topic_id: outside.id, follower_id: user.id)
    response = ApiClient.new.get("/forum?node=#{node.slug}&following=true&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    list = document.xpath_node("//section[@id='forum-topics']").not_nil!
    next_path = list.xpath_node("./div/nav/a").not_nil!["href"]

    list.xpath_nodes(".//article").size.should eq(20)
    list.content.should contain("第 1 / 2 页")
    URI.parse(next_path).path.should eq("/forum")
    URI.parse(next_path).query_params["following"].should eq("true")
    URI.parse(next_path).query_params["node"].should eq(node.slug)
    URI.parse(next_path).query_params["page"].should eq("2")
    response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main | //header | //footer | //aside").should be_nil
    document.xpath_nodes("//section[@id='forum-topics']//article").size.should eq(1)
    document.content.should contain(topics.first.title)
    document.content.should_not contain("未关注的主题")
    document.content.should_not contain(outside.title)
    document.content.should contain("第 2 / 2 页")
    previous_path = document.xpath_node("//section/div/nav/a").not_nil!["href"]
    URI.parse(previous_path).path.should eq("/forum")
    URI.parse(previous_path).query_params["following"].should eq("true")
    URI.parse(previous_path).query_params["node"].should eq(node.slug)
    URI.parse(previous_path).query_params["page"].should eq("1")

    response = ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true").get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main//h1").not_nil!.content.should eq(node.name)
    document.xpath_node("//main//header//div[@class='segmented-control']/a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("仅关注")
    document.xpath_node("//main//aside/nav").should_not be_nil
  end

  it "hides deleted and unfollowed topics, and restores followed topics with their subscriptions" do
    author = UserFactory.create
    user = UserFactory.create
    node = followed_topics_node
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "可恢复的关注主题", content: "正文")
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: user.id)
    DeleteTopic.delete!(topic)
    path = "/forum?following=true&backdoor_user_id=#{user.id}"
    response = ApiClient.new.get(path)

    XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!.content.should_not contain(topic.title)
    TopicFollowQuery.new.topic_id(topic.id).follower_id(user.id).any?.should be_true
    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    response = ApiClient.new.get(path)
    XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!.content.should contain(topic.title)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      ApiClient.new.delete("/forum/#{topic.id}/follow?backdoor_user_id=#{user.id}").status_code.should eq(200)
    end
    response = ApiClient.new.get(path)
    XML.parse_html(response.body).xpath_node("//section[@id='forum-topics']").not_nil!.content.should_not contain(topic.title)
  end

  it "shows a useful translated empty state in full pages and partial responses" do
    user = UserFactory.create

    {"zh-CN" => "没有符合条件的关注主题", "en" => "No followed topics here"}.each do |locale, message|
      [ApiClient.new, ApiClient.new.headers("HX-Request-Type": "partial")].each do |client|
        response = client.get("/forum?following=true&locale=#{locale}&backdoor_user_id=#{user.id}")
        document = XML.parse_html(response.body)
        list = document.xpath_node("//section[@id='forum-topics']").not_nil!

        response.status_code.should eq(200)
        list.content.should contain(message)
        list.xpath_node(".//nav").should be_nil
      end
    end
  end
end
