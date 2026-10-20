require "../spec_helper"

describe "Page positioning" do
  it "keeps the document sidebar in its reserved column" do
    response = ApiClient.new.get("/docs/index")
    document = XML.parse_html(response.body)
    sidebar = document.xpath_node("//main/aside/header[@id='sidebar']").not_nil!

    response.status_code.should eq(200)
    document.xpath_node("//header[@class='site-navbar']").should_not be_nil
    sidebar["class"].should contain("desktop-sidebar")
    sidebar["class"].should contain("lg:w-80")
    sidebar.parent.not_nil!["class"].should contain("lg:w-80")
  end

  it "shares the fixed node navigation on topic lists and details, but not editors" do
    user = UserFactory.create
    node = SaveNode.create!(name: "布局测试", slug: "layout-test", summary: "布局测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "布局测试主题", content: "测试正文")

    {"/forum", "/forum/#{topic.id}"}.each do |path|
      response = ApiClient.new.get(path)
      document = XML.parse_html(response.body)
      sidebar = document.xpath_node("//main//aside/nav").not_nil!

      response.status_code.should eq(200)
      sidebar["class"].should contain("desktop-sidebar")
      sidebar["class"].should contain("lg:[--sidebar-gap:2.5rem]")
      sidebar.parent.not_nil!["class"].should contain("lg:w-56")
      sidebar.xpath_node(".//a[@href='/forum?node=layout-test']").should_not be_nil
    end

    {"/forum/new", "/forum/#{topic.id}/edit"}.each do |path|
      response = ApiClient.new.get("#{path}?backdoor_user_id=#{user.id}")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//main//aside").should be_nil
    end
  end

  it "reserves a fixed admin navigation column beside the page heading" do
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "layout-admin@example.com"
    admin = UserFactory.create &.email("layout-admin@example.com")
    response = ApiClient.new.get("/admin?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    sidebar = document.xpath_node("//main//aside/nav").not_nil!

    response.status_code.should eq(200)
    sidebar["class"].should contain("desktop-sidebar")
    sidebar["class"].should contain("lg:[--sidebar-gap:2.5rem]")
    sidebar.parent.not_nil!["class"].should contain("lg:w-56")
    document.xpath_node("//main/section/div/div/header/h1").not_nil!.content.should eq("后台管理")
    {"/admin", "/admin/nodes", "/user_audits", "/admin/trash"}.each do |path|
      sidebar.xpath_node(".//a[@href='#{path}']").should_not be_nil
    end
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "keeps the account-history header outside its keyboard-accessible scrolling list" do
    user = UserFactory.create
    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    header = document.xpath_node("//main//section/header").not_nil!

    response.status_code.should eq(200)
    header["class"].should contain("shrink-0")
    header["class"].should_not contain("sticky")
    header.xpath_node(".//a[@href='#{Users::Show.with(login_name: user.login_name).path}']").should_not be_nil
    panel = header.parent.not_nil!
    region = panel.xpath_node("./div[@role='region']").not_nil!

    panel["class"].should contain("max-h-[70dvh]")
    panel["class"].should contain("overflow-hidden")
    region["class"].should contain("overflow-y-auto")
    region["tabindex"].should eq("0")
    region["aria-labelledby"].should eq(header.xpath_node(".//h1").not_nil!["id"])
  end
end
