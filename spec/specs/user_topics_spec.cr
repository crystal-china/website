require "../spec_helper"

private def user_topics_node : Node
  SaveNode.create!(name: "个人主页测试", slug: "user-topics", summary: "测试", color: "#0284c7", position: 0)
end

private def user_topics_reply(topic : Topic, user : User, at : Time) : Comment
  thread = CommentThreadQuery.new.topic_id(topic.id).first

  CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "参与讨论", created_at: at)
end

private def profile_topic_titles(document : XML::Node) : Array(String)
  document.xpath_nodes("//section[@id='user-topics']//article//h2/a").map(&.content)
end

describe "User profile topics" do
  it "publicly lists only the user's kept topics by creation time, not last activity" do
    user = UserFactory.create
    other = UserFactory.create
    node = user_topics_node
    at = Time.utc - 4.days
    older = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "较早创建", content: "正文", created_at: at)
    newer = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "最近创建", content: "正文", created_at: at + 1.day)
    deleted = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "已删除主题", content: "正文")
    CreateTopic.create!(user_id: other.id, node_id: node.id, title: "其他人的主题", content: "正文")
    DeleteTopic.delete!(deleted)
    user_topics_reply(older, other, at + 2.days)
    response = ApiClient.new.get(Users::Show.with(login_name: user.login_name).path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    profile_topic_titles(document).should eq([newer.title, older.title])
    document.xpath_node("//main//h1").not_nil!.content.should contain(user.nickname)
    document.xpath_nodes("//section[@id='user-topics']//article//time").map(&.["datetime"]).should eq([newer.created_at.to_rfc3339, older.created_at.to_rfc3339])
    document.xpath_node("//section[@id='user-topics']//article[2]").not_nil!.content.should contain("1 条回复")
    document.xpath_node("//section[@id='user-topics']//a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("创建的主题")
  end

  it "lists individual replies in time order, including nested and self replies, with safe excerpts and direct links" do
    user = UserFactory.create
    other = UserFactory.create
    node = user_topics_node
    at = Time.utc - 4.days
    first = CreateTopic.create!(user_id: other.id, node_id: node.id, title: "先回复的主题", content: "正文")
    second = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "自己的主题", content: "正文")
    root = user_topics_reply(first, other, at)
    middle = CreateComment.create!(user_id: other.id, parent_id: root.id, content: "中间评论", created_at: at)
    nested = CreateComment.create!(user_id: user.id, parent_id: middle.id, content: "本人深层回复", created_at: at + 1.day)
    DeleteComment.delete!(middle)
    earlier = user_topics_reply(second, user, at)
    second_thread = CommentThreadQuery.new.topic_id(second.id).first
    latest = CreateComment.create!(user_id: user.id, comment_thread_id: second_thread.id, content: "<script>alert('test')</script> 这是最后一条回复", created_at: at + 2.days)
    user_topics_reply(first, other, at + 3.days)
    doc = DocContent.sync("/docs/index", "文档")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "文档评论")
    response = ApiClient.new.get(Users::Show.with(login_name: user.login_name, show_replies: true).path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    profile_topic_titles(document).should eq([second.title, first.title, second.title])
    articles = document.xpath_nodes("//section[@id='user-topics']//article")
    articles.map(&.xpath_node(".//time").not_nil!["datetime"]).should eq([latest.created_at.to_rfc3339, nested.created_at.to_rfc3339, earlier.created_at.to_rfc3339])
    [latest, nested, earlier].each_with_index do |comment, index|
      excerpt = articles[index].xpath_node("./a").not_nil!

      excerpt["href"].should eq(Comments::Show.with(id: comment.id).path)
      excerpt.content.should eq(comment.content[0, 240])
    end
    articles.first.xpath_node(".//script").should be_nil
    document.xpath_node("//section[@id='user-topics']//a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("最近回复")
    target = ApiClient.new.get(Comments::Show.with(id: nested.id).path)
    target.status_code.should eq(303)
    target.headers["Location"].should eq("/forum/#{first.id}?comment_id=#{nested.id}")
  end

  it "respects deleted replies, roots, topics and restoration" do
    user = UserFactory.create
    author = UserFactory.create
    node = user_topics_node
    at = Time.utc - 3.days
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "可见性测试", content: "正文")
    earlier = user_topics_reply(topic, user, at)
    root = user_topics_reply(topic, author, at)
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "较新子回复", created_at: at + 1.day)
    newest = user_topics_reply(topic, user, at + 2.days)
    DeleteComment.delete!(newest)

    visible_replies = -> { CommentQuery.new.user_id(user.id).publicly_visible_topic_comments.created_at.desc_order.id.desc_order.map(&.id) }

    visible_replies.call.should eq([child.id, earlier.id])
    DeleteComment.delete!(root)
    visible_replies.call.should eq([earlier.id])
    DeleteComment.delete!(earlier)
    visible_replies.call.should be_empty
    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    visible_replies.call.should eq([child.id])
    DeleteTopic.delete!(topic)
    visible_replies.call.should be_empty
    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    visible_replies.call.should eq([child.id])
  end

  it "paginates both lists locally, resets the page when switching and supports full history restoration" do
    user = UserFactory.create
    node = user_topics_node
    at = Time.utc - 1.day
    topics = Array.new(21) do |index|
      topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "个人分页 #{index}", content: "正文", created_at: at)
      2.times { user_topics_reply(topic, user, at) }
      topic
    end

    [false, true].each do |show_replies|
      path = Users::Show.with(login_name: user.login_name, show_replies: show_replies ? true : nil).path
      response = ApiClient.new.get(path)
      document = XML.parse_html(response.body)
      next_path = document.xpath_node("//section[@id='user-topics']//nav/a").not_nil!["href"]

      expected_titles = topics.reverse.flat_map { |topic| Array.new(show_replies ? 2 : 1, topic.title) }

      profile_topic_titles(document).should eq(expected_titles.first(20))
      URI.parse(next_path).query_params["show_replies"]?.should eq(show_replies ? "true" : nil)
      URI.parse(next_path).query_params["page"].should eq("2")
      response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//main | //h1 | //footer").should be_nil
      profile_topic_titles(document).should eq(expected_titles.skip(20).first(20))
      document.content.should contain("第 2 / #{show_replies ? 3 : 2} 页")
      document.xpath_nodes("//div[@class='segmented-control']/a").each do |link|
        URI.parse(link["href"]).query_params["page"]?.should be_nil
        link.parent.not_nil!.parent.not_nil!["hx-target:inherited"].should eq("#user-topics")
      end
      # 主题和节点链接不继承列表的局部替换目标。
      document.xpath_node("//article//h2/a/ancestor::*[@*[name()='hx-target:inherited']]").should be_nil

      response = ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true").get(next_path)
      document = XML.parse_html(response.body)
      document.xpath_node("//main//h1").not_nil!.content.should contain(user.nickname)
      profile_topic_titles(document).should eq(expected_titles.skip(20).first(20))

      if show_replies
        response = ApiClient.new.headers("HX-Request-Type": "partial").get("#{path}&page=3")
        document = XML.parse_html(response.body)
        profile_topic_titles(document).should eq([topics.first.title, topics.first.title])
        document.content.should contain("第 3 / 3 页")
      end
    end
  end

  it "translates empty lists and returns 404 for unknown accounts" do
    user = UserFactory.create

    {"zh-CN" => ["还没有创建主题。", "还没有回复。"], "en" => ["No topics created yet.", "No replies yet."]}.each do |locale, messages|
      [false, true].each_with_index do |show_replies, index|
        path = Users::Show.with(login_name: user.login_name, show_replies: show_replies).path
        response = ApiClient.new.headers("HX-Request-Type": "partial").get("#{path}&locale=#{locale}")
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        document.content.should contain(messages[index])
        document.xpath_node("//nav").should be_nil
      end
    end

    ApiClient.new.get("/users/missing-user/profile").status_code.should eq(404)
  end
end
