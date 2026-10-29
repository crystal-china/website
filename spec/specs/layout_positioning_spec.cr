require "../spec_helper"

describe "Page positioning" do
  it "uses the shared page spacing for ordinary pages" do
    user = UserFactory.create
    public_paths = [
      "/",
      "/sign_in",
      "/sign_up",
      "/password_reset_requests/new",
      "/forum",
    ]
    private_paths = [
      "/me",
      Users::Show.with(login_name: user.login_name).path,
      Users::Edit.with(id: user.id).path,
      UserAudits::Index.path,
    ]

    (public_paths + private_paths.map { |path| "#{path}?backdoor_user_id=#{user.id}" }).each do |path|
      response = ApiClient.new.get(path)

      response.status_code.should eq(200)
      document = XML.parse_html(response.body)
      container = document.xpath_node("//main/*[contains(concat(' ', @class, ' '), ' page-content ')]").not_nil!
      container["class"].split.should_not contain("py-10")
      container["class"].split.should_not contain("py-12")
    end
  end

  it "keeps the document sidebar in its reserved column" do
    response = ApiClient.new.get("/docs/index")
    document = XML.parse_html(response.body)
    sidebar = document.xpath_node("//main/aside/header[@id='sidebar']").not_nil!

    response.status_code.should eq(200)
    document.xpath_node("//header[@class='site-navbar']").should_not be_nil
    sidebar["class"].should contain("desktop-sidebar")
    sidebar["class"].should contain("lg:w-80")
    sidebar.parent.not_nil!["class"].should contain("lg:w-80")
    document.xpath_node("//main[contains(@class, 'page-content')]").should be_nil
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
      sidebar.xpath_node("ancestor::section[contains(@class, 'page-content')]").should_not be_nil
      sidebar.parent.not_nil!["class"].should contain("lg:w-56")
      sidebar.xpath_node(".//a[@href='/forum?node=layout-test']").should_not be_nil
    end

    {"/forum/new", "/forum/#{topic.id}/edit"}.each do |path|
      response = ApiClient.new.get("#{path}?backdoor_user_id=#{user.id}")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//main//aside").should be_nil
    end
  end

  it "puts topic replies before the editor but keeps the document editor first" do
    user = UserFactory.create
    node = SaveNode.create!(name: "评论布局", slug: "comment-layout", summary: "评论布局测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "评论顺序", content: "测试正文")

    {"/forum/#{topic.id}", "/docs/index"}.each do |path|
      response = ApiClient.new.get("#{path}?backdoor_user_id=#{user.id}")
      document = XML.parse_html(response.body)
      section = document.xpath_node("//section[@id='form_with_comments']").not_nil!

      response.status_code.should eq(200)
      section.xpath_nodes("./div[@id='comments']").size.should eq(1)
      section.xpath_nodes("./form[@id='tab-form']").size.should eq(1)
      section.xpath_node("./form//div[@id='comments']").should be_nil

      if path.starts_with?("/forum/")
        section.xpath_node("./div[@id='comments']/following-sibling::form[@id='tab-form']").should_not be_nil
      else
        section.xpath_node("./form[@id='tab-form']/following-sibling::div[@id='comments']").should_not be_nil
      end
    end
  end

  it "keeps admin navigation beside the content and reserves page headings for node forms" do
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "layout-admin@example.com"
    admin = UserFactory.create &.email("layout-admin@example.com")
    response = ApiClient.new.get("/admin?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    sidebar = document.xpath_node("//main//aside/nav").not_nil!

    response.status_code.should eq(200)
    sidebar["class"].should contain("desktop-sidebar")
    sidebar.xpath_node("ancestor::section[contains(@class, 'page-content')]").should_not be_nil
    sidebar.parent.not_nil!["class"].should contain("lg:w-56")

    {"/admin", "/admin/nodes", "/user_audits", "/admin/trash"}.each do |path|
      sidebar.xpath_node(".//a[@href='#{path}']").should_not be_nil
    end

    node = SaveNode.create!(
      name: "布局节点",
      slug: "admin-layout",
      summary: "布局测试",
      color: "#16a34a",
      position: 0
    )

    paths = {"/admin", "/admin/nodes", "/admin/trash", "/user_audits"}

    paths.each do |path|
      response = ApiClient.new.get("#{path}?backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//main//h1 | //main//h2").should be_empty
      document.xpath_node("//main//aside/nav").should_not be_nil
    end

    {
      "/admin/nodes/new"             => "新增节点",
      "/admin/nodes/#{node.id}/edit" => "编辑节点",
    }.each do |path, title|
      response = ApiClient.new.get("#{path}?locale=zh-CN&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)
      header = document.xpath_node("//main//section/header").not_nil!

      response.status_code.should eq(200)
      header.xpath_node("./h2").not_nil!.content.should eq(title)
      header.xpath_node("./p").should be_nil
      document.xpath_node("//main//aside/nav").should_not be_nil
    end
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "keeps account history in normal page flow with a compact header" do
    user = UserFactory.create
    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    header = document.xpath_node("//main//section/header").not_nil!

    response.status_code.should eq(200)
    header["class"].should contain("py-3")
    header["class"].should_not contain("sticky")
    header.xpath_node(".//h1").should be_nil
    header.xpath_node(".//a[@href='#{Users::Show.with(login_name: user.login_name).path}']").should_not be_nil
    panel = header.parent.not_nil!

    panel["class"].should contain("mx-auto")
    panel["class"].should contain("max-w-3xl")
    panel["class"].should_not contain("max-h-")
    panel["class"].should_not contain("overflow-")
    panel.xpath_node("./section[@id='user-audits-list']").should_not be_nil
    header.xpath_node(".//p").should be_nil
    panel.xpath_node(".//*[@id='user-audits-scroll']").should be_nil
  end
end
