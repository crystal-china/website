require "../spec_helper"

describe Shared::Pagination do
  it "hides pagination for zero or one page, including disabled controls" do
    {0, 1, App::DEFAULT_PER_PAGE}.each do |count|
      pages = Lucky::Paginator.new(
        page: 1,
        per_page: App::DEFAULT_PER_PAGE,
        item_count: count,
        full_path: "/forum"
      )
      html = Shared::Pagination.new(
        pages: pages
      ).render_to_string

      html.should be_empty
    end
  end

  it "keeps filters on ordinary links and always shows disabled controls" do
    {1, 2}.each do |page|
      pages = Lucky::Paginator.new(
        page: page,
        per_page: App::DEFAULT_PER_PAGE,
        item_count: App::DEFAULT_PER_PAGE + 1,
        full_path: "/forum?node=help"
      )
      html = Shared::Pagination.new(
        pages: pages
      ).render_to_string
      document = XML.parse_html(html)
      link = document.xpath_node("//nav/a").not_nil!
      disabled = document.xpath_node("//span[contains(@class, 'cursor-not-allowed')]").not_nil!
      params = URI.parse(link["href"]).query_params

      params["node"].should eq("help")
      params["page"].should eq(page == 1 ? "2" : "1")
      disabled.content.should eq(page == 1 ? "上一页" : "下一页")
      link["hx-get"]?.should be_nil
      link["hx-target"]?.should be_nil
      link["hx-swap"]?.should be_nil
      document.xpath_node("//nav").not_nil!.content.should contain("第 #{page} / 2 页")
    end
  end

  it "keeps custom styles and translated labels without prescribing HTMX behavior" do
    pages = Lucky::Paginator.new(
      page: 1,
      per_page: App::DEFAULT_PER_PAGE,
      item_count: App::DEFAULT_PER_PAGE + 1,
      full_path: "/notifications?locale=en"
    )
    html = Rosetta.with_locale("en") do
      Shared::Pagination.new(
        pages: pages,
        classes: "border-t p-4"
      ).render_to_string
    end
    document = XML.parse_html(html)
    nav = document.xpath_node("//nav").not_nil!
    link = nav.xpath_node("./a").not_nil!

    nav["class"].should eq("border-t p-4")
    nav["aria-label"]?.should be_nil
    nav.xpath_nodes("./a").size.should eq(1)
    nav.content.should eq("PreviousPage 1 of 2Next")
    link["hx-get"]?.should be_nil
    link["hx-target"]?.should be_nil
    link["hx-swap"]?.should be_nil
    URI.parse(link["href"]).query_params["locale"].should eq("en")
  end

  it "reuses pagination on community and trash pages without losing their filters" do
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "pagination-admin@example.com"
    admin = UserFactory.create &.email("pagination-admin@example.com")
    node = SaveNode.create!(name: "分页测试", slug: "pagination-test", summary: "分页测试", color: "#16a34a", position: 0)
    client = ApiClient.new

    {"comments", "topics"}.each do |kind|
      response = client.get("/admin/trash?kind=#{kind}&backdoor_user_id=#{admin.id}")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//main//nav[span]").should be_nil
    end

    topics = Array.new(App::DEFAULT_PER_PAGE + 1) do |index|
      CreateTopic.create!(user_id: admin.id, node_id: node.id, title: "分页测试 #{index}", content: "分页正文")
    end
    response = client.get("/forum?node=#{node.slug}")
    nav = XML.parse_html(response.body).xpath_node("//main//nav[a[.='下一页']]").not_nil!
    next_path = nav.xpath_node("./a").not_nil!["href"]

    URI.parse(next_path).query_params["node"].should eq(node.slug)
    nav.xpath_node("./span[contains(@class, 'cursor-not-allowed')]").not_nil!.content.should eq("上一页")
    client.get(next_path).body.should contain("第 2 / 2 页")

    topics.each { |topic| DeleteTopic.delete!(topic) }
    response = client.get("/admin/trash?kind=topics&backdoor_user_id=#{admin.id}")
    nav = XML.parse_html(response.body).xpath_node("//main//nav[a[.='下一页']]").not_nil!
    next_path = nav.xpath_node("./a").not_nil!["href"]

    URI.parse(next_path).query_params["kind"].should eq("topics")
    nav.xpath_node("./span[contains(@class, 'cursor-not-allowed')]").not_nil!.content.should eq("上一页")
    client.get(next_path).body.should contain("第 2 / 2 页")
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end
end
