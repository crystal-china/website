require "../spec_helper"

describe Shared::UserName do
  it "shows both names and links to the public profile without relying on a tooltip" do
    user = UserFactory.create &.nickname("小明").login_name("Xiao.Ming")
    document = XML.parse_html(Shared::UserName.new(user: user).render_to_string)
    link = document.xpath_node("//a").not_nil!

    link["href"].should eq("/users/Xiao.Ming/profile")
    link.xpath_node(".//span[@class='user-name-nickname']").not_nil!.content.should eq("小明")
    link.xpath_node(".//span[@class='user-name-login']").not_nil!.content.should eq("@Xiao.Ming")
    document.xpath_node("//*[@title]").should be_nil
  end

  it "escapes nicknames instead of interpreting them as HTML" do
    user = UserFactory.create &.nickname("小明 <script>alert(1)</script> & friends")
    document = XML.parse_html(Shared::UserName.new(user: user).render_to_string)

    document.xpath_node("//script").should be_nil
    document.xpath_node("//span[@class='user-name-nickname']").not_nil!.content.should eq(user.nickname)
  end

  it "supports stacked names without generating an interactive element" do
    user = UserFactory.create
    document = XML.parse_html(Shared::UserName.new(user: user, linked: false, stacked: true).render_to_string)

    document.xpath_node("//a").should be_nil
    document.xpath_node("//span[@class='user-name user-name-stacked']").should_not be_nil
    document.xpath_node("//span[@class='user-name-login']").not_nil!.content.should eq("@#{user.login_name}")
  end

  it "does not nest a profile link inside the notification submit button" do
    recipient = UserFactory.create
    actor = UserFactory.create &.nickname("小明").login_name("xiaoming")
    SaveNotification.create!(
      user_id: recipient.id,
      actor_id: actor.id,
      kind: :mention,
      url: "/docs/index",
      source_title: "前言",
      excerpt: "欢迎一起讨论 Crystal。"
    )
    response = ApiClient.new.get("/notifications?backdoor_user_id=#{recipient.id}")
    document = XML.parse_html(response.body)
    button = document.xpath_node("//form[@action='/notifications/#{NotificationQuery.new.user_id(recipient.id).first.id}/read']//button").not_nil!

    response.status_code.should eq(200)
    button.xpath_node(".//a").should be_nil
    button.xpath_node(".//span[@class='user-name-nickname']").not_nil!.content.should eq("小明")
    button.xpath_node(".//span[@class='user-name-login']").not_nil!.content.should eq("@xiaoming")
  end

  it "uses inline names and vertically centered headers for root comments and replies" do
    user = UserFactory.create &.nickname("小明").login_name("xiaoming")
    doc = SaveDoc.create!(path_index: "/docs/comment-header", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "child")

    {
      root  => "/htmx/comments?comment_thread_id=#{thread.id}",
      child => "/htmx/comments?root_id=#{root.id}",
    }.each do |comment, path|
      response = ApiClient.new.get(path)
      document = XML.parse_html(response.body)
      header = document.xpath_node("//div[@id='comment-#{comment.id}-content']/header").not_nil!
      name = header.xpath_node(".//a[@class='user-name']").not_nil!

      response.status_code.should eq(200)
      header["class"].split.should contain("items-center")
      header["class"].split.should_not contain("items-start")
      header.xpath_node(".//*[contains(@class, 'user-name-stacked')]").should be_nil
      name.xpath_node("./span[@class='user-name-nickname']").not_nil!.content.should eq("小明")
      name.xpath_node("./span[@class='user-name-login']").not_nil!.content.should eq("@xiaoming")
      header.xpath_node(".//time").should_not be_nil
    end
  end
end
