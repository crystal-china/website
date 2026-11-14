require "../spec_helper"

describe "Community partial navigation" do
  it "synchronizes nodes, filters, title and analytics, with complete pages for refreshes" do
    author = UserFactory.create
    reader = UserFactory.create
    node = SaveNode.create!(
      name: "导航节点",
      slug: "forum-navigation",
      summary: "节点介绍",
      color: "#16a34a",
      position: 0
    )
    other_node = SaveNode.create!(
      name: "其他节点",
      slug: "other-navigation",
      summary: "其他节点介绍",
      color: "#0284c7",
      position: 1
    )
    topic = CreateTopic.create!(
      user_id: author.id,
      node_id: node.id,
      title: "节点内已关注主题",
      content: "正文"
    )
    unfollowed = CreateTopic.create!(
      user_id: author.id,
      node_id: node.id,
      title: "节点内未关注主题",
      content: "正文"
    )
    outside = CreateTopic.create!(
      user_id: author.id,
      node_id: other_node.id,
      title: "节点外已关注主题",
      content: "正文"
    )

    [topic, outside].each do |followed_topic|
      SaveTopicFollow.create!(topic_id: followed_topic.id, follower_id: reader.id)
    end

    path = "/forum?node=#{node.slug}&following=true&only_show_unread=true&backdoor_user_id=#{reader.id}"
    response = ApiClient.new.headers("HX-Request-Type": "partial").get(path)
    document = XML.parse_html(response.body)
    community = document.xpath_node("//section[@id='forum-content']").not_nil!
    header = community.xpath_node(".//header[@id='forum-list-header']").not_nil!
    navigation = community.xpath_node(".//aside[nav]/nav").not_nil!
    list = document.xpath_node("//section[@id='forum-topics']").not_nil!
    expected_title = "#{node.name} - 社区"

    response.status_code.should eq(200)
    response.body.should_not contain("<!DOCTYPE")
    document.xpath_node("//main | //footer").should be_nil
    document.xpath_nodes("//hx-partial").size.should eq(9)
    document.xpath_node("//title").not_nil!.content.should eq("Crystal China - #{expected_title}")
    document.xpath_node("//hx-partial[@hx-target='#page-analytics']/div").not_nil!["data-page-title"].should eq(expected_title)
    document.xpath_node("//hx-partial/link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/forum")
    header.xpath_node(".//h1").not_nil!.content.should eq(node.name)
    header.content.should contain(node.summary)
    list.xpath_nodes(".//article//h2/a").map(&.content).should eq([topic.title])
    list.content.should_not contain(unfollowed.title)
    list.content.should_not contain(outside.title)

    selected_filters = header.xpath_nodes(".//div[@class='segmented-control']/a[contains(@class, 'segmented-option-active')]")

    selected_filters.map(&.content).should eq(["仅关注", "近七天未读"])

    header.xpath_nodes(".//div[@class='segmented-control']/a").each do |link|
      query = URI.parse(link["href"]).query_params
      target = link.xpath_node("ancestor::div[@*[name()='hx-target:inherited']]").not_nil!

      query["node"].should eq(node.slug)
      query["page"]?.should be_nil
      target["hx-target:inherited"].should eq("#forum-content")
      target["hx-sync:inherited"].should eq("#forum-content:replace")
    end

    navigation.xpath_nodes(".//a").each do |link|
      query = URI.parse(link["href"]).query_params

      query["following"].should eq("true")
      query["only_show_unread"].should eq("true")
      query["page"]?.should be_nil
    end

    navigation.xpath_nodes(".//a[contains(@class, 'bg-gray-900')]").map(&.content).should eq([node.name])
    navigation["hx-target:inherited"].should eq("#forum-content")
    navigation["hx-sync:inherited"].should eq("#forum-content:replace")

    new_topic_link = header.xpath_node(".//a[@href='/forum/new']").not_nil!
    topic_link = list.xpath_node(".//h2/a").not_nil!
    author_link = list.xpath_node(".//a[@href='#{Users::Show.with(login_name: author.login_name).path}']").not_nil!

    [new_topic_link, author_link].each do |link|
      link["hx-target"]?.should be_nil
      link.xpath_node("ancestor::*[@*[name()='hx-target:inherited']]").should be_nil
    end

    topic_link["hx-target"].should eq("#forum-content")
    topic_link["hx-sync"].should eq("#forum-content:replace")

    node_link = list.xpath_node(".//article//p/a").not_nil!

    node_link["hx-target"].should eq("#forum-content")

    {
      ApiClient.new,
      ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true"),
    }.each do |client|
      response = client.get(path)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.body.should contain("<!DOCTYPE")
      document.xpath_node("//main//header[@id='forum-list-header']").should_not be_nil
      document.xpath_node("//main//section[@id='forum-content']").should_not be_nil
      document.xpath_node("//main//section[@id='forum-content']//aside[nav]/nav").not_nil!["hx-target:inherited"].should eq("#forum-content")
      document.xpath_nodes("//main//section[@id='forum-topics']//h2/a").map(&.content).should eq([topic.title])
      document.xpath_node("//hx-partial").should be_nil
      document.xpath_node("//link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/forum")
    end

    response = ApiClient.new.get("/forum/#{topic.id}?following=true&only_show_unread=true&backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)
    navigation = document.xpath_node("//section[@id='forum-content']//aside[nav]/nav").not_nil!

    response.status_code.should eq(200)
    navigation["hx-target:inherited"].should eq("#forum-content")
  end

  it "navigates from the list to a topic and back without retaining the topic sidebar or comments" do
    author = UserFactory.create
    reader = UserFactory.create
    node = SaveNode.create!(
      name: "双向导航",
      slug: "bidirectional-navigation",
      summary: "测试列表和详情切换",
      color: "#16a34a",
      position: 0
    )
    topic = CreateTopic.create!(
      user_id: author.id,
      node_id: node.id,
      title: "双向局部刷新主题",
      content: "详情正文 @#{reader.login_name}"
    )
    notice = NotificationQuery.new.user_id(reader.id).for_target(topic).first

    SaveTopicFollow.create!(topic_id: topic.id, follower_id: reader.id)

    client = ApiClient.new.headers("HX-Request-Type": "partial")
    path = "/forum?node=#{node.slug}&following=true&only_show_unread=true&backdoor_user_id=#{reader.id}"
    response = client.get(path)
    document = XML.parse_html(response.body)
    topic_link = document.xpath_node("//section[@id='forum-content']//h2/a").not_nil!
    topic_path = "#{topic_link["href"]}&backdoor_user_id=#{reader.id}"

    topic_link["hx-target"].should eq("#forum-content")

    response = client.get(topic_path)
    document = XML.parse_html(response.body)
    community = document.xpath_node("//section[@id='forum-content']").not_nil!
    canonical_url = "#{Lucky::RouteHelper.settings.base_uri}/forum/#{topic.id}"
    navigation = community.xpath_node(".//aside[nav]/nav").not_nil!
    return_path = navigation.xpath_nodes(".//a").find!(&.["href"].includes?("node=#{node.slug}"))["href"]
    bell = document.xpath_node("//hx-partial[@hx-target='#notification-status']//*[@id='notification-status']").not_nil!

    response.status_code.should eq(200)
    response.body.should_not contain("<!DOCTYPE")
    document.xpath_node("//main | //footer").should be_nil
    community.xpath_node(".//article/header/h1").not_nil!.content.should eq(topic.title)
    community.content.should contain("详情正文")
    community.xpath_node(".//section[@id='form_with_comments']/div[@id='comments']").should_not be_nil
    community.xpath_node(".//dialog[@id='comment-dialog']").should_not be_nil
    community.xpath_node(".//aside[not(nav)]").should_not be_nil
    community.xpath_node(".//section[@id='forum-topics']").should be_nil
    community.xpath_node(".//article/header/div/p/a").not_nil!["hx-target"].should eq("#forum-content")
    document.xpath_node("//title").not_nil!.content.should eq("Crystal China - #{topic.title}")
    document.xpath_node("//hx-partial/link[@rel='canonical']").not_nil!["href"].should eq(canonical_url)
    document.xpath_node("//hx-partial/meta[@property='og:url']").not_nil!["content"].should eq(canonical_url)
    document.xpath_node("//hx-partial/meta[@property='og:title']").not_nil!["content"].should eq(topic.title)
    document.xpath_node("//hx-partial/meta[@name='twitter:title']").not_nil!["content"].should eq(topic.title)
    document.xpath_node("//hx-partial[@hx-target='#page-analytics']/div").not_nil!["data-page-title"].should eq(topic.title)
    bell.xpath_node(".//span[@aria-hidden='true']").should be_nil
    notice.reload.read_at.should_not be_nil
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false

    guest_response = ApiClient.new.headers("HX-Request-Type": "partial").get("/forum/#{topic.id}")
    guest_document = XML.parse_html(guest_response.body)

    guest_response.status_code.should eq(200)
    guest_response.body.should_not contain("<!DOCTYPE")
    guest_document.xpath_node("//section[@id='forum-content']//article/header/h1").not_nil!.content.should eq(topic.title)
    guest_document.xpath_node("//hx-partial[@hx-target='#notification-status']").should be_nil
    guest_document.xpath_node("//*[@data-draft-key]").should be_nil

    response = client.get("#{return_path}&backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)
    community = document.xpath_node("//section[@id='forum-content']").not_nil!

    response.status_code.should eq(200)
    response.body.should_not contain("<!DOCTYPE")
    document.xpath_node("//main | //footer").should be_nil
    community.xpath_node(".//header[@id='forum-list-header']/div/h1").not_nil!.content.should eq(node.name)
    community.xpath_node(".//section[@id='forum-topics']/p").should_not be_nil
    community.xpath_node(".//section[@id='form_with_comments'] | .//dialog[@id='comment-dialog']").should be_nil
    community.xpath_node(".//aside[not(nav)]").should be_nil
    document.xpath_node("//hx-partial/link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/forum")

    {
      ApiClient.new,
      ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true"),
    }.each do |full_page_client|
      response = full_page_client.get(topic_path)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.body.should contain("<!DOCTYPE")
      document.xpath_node("//main//section[@id='forum-content']//article/header/h1").not_nil!.content.should eq(topic.title)
      document.xpath_node("//head/link[@rel='canonical']").not_nil!["href"].should eq(canonical_url)
      document.xpath_node("//hx-partial").should be_nil
    end
  end
end
