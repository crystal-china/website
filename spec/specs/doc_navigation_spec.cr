require "../spec_helper"

describe "Document partial navigation" do
  around_each do |example|
    VIEW_COUNT_CACHE.clear

    Dir.cd(File.expand_path("../fixtures/doc_navigation", __DIR__)) do
      DocNavigation.load
      example.run
    end
  ensure
    DocNavigation.load
    VIEW_COUNT_CACHE.clear
  end

  it "switches documents through the sidebar and pager while keeping each document's content and metadata together" do
    user = UserFactory.create
    client = ApiClient.new
    response = client.get("/docs/index?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    sidebar = document.xpath_node("//*[@id='sidebar']/nav").not_nil!
    pager = document.xpath_node("//article/nav/div").not_nil!
    next_path = pager.xpath_node(".//a[@href='/docs/chapter']").not_nil!["href"]
    community_link = document.xpath_node("//article//a[@href='/forum']").not_nil!

    response.status_code.should eq(200)
    response.body.should contain("<!DOCTYPE")
    document.xpath_node("//header[@class='site-navbar']").should_not be_nil
    document.xpath_node("//*[@id='search_dialog']").should_not be_nil
    document.xpath_node("//*[@id='search_dialog']/ancestor::*[@id='doc-content']").should be_nil
    document.xpath_node("//*[@id='doc-content']/main").should_not be_nil
    document.xpath_node("//*[@id='doc-content']//dialog[@id='comment-dialog']").should_not be_nil

    [sidebar, pager].each do |navigation|
      navigation["hx-target:inherited"].should eq("#doc-content")
      navigation["hx-swap:inherited"].should eq("outerHTML show:top showTarget:body")
      navigation["hx-sync:inherited"].should eq("#doc-content:replace")
    end

    community_link["hx-target"]?.should be_nil
    community_link.xpath_node("ancestor::*[@*[name()='hx-target:inherited']]").should be_nil

    client.headers("HX-Request-Type": "partial")
    response = client.get("#{next_path}?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    content = document.xpath_node("//div[@id='doc-content']").not_nil!
    child_doc = DocQuery.new.path_index(next_path).first
    child_thread = CommentThreadQuery.new.doc_id(child_doc.id).first
    form = content.xpath_node(".//section[@id='form_with_comments']/form").not_nil!
    comments = content.xpath_node(".//div[@id='comments']").not_nil!
    previous_path = content.xpath_node(".//article/nav//a[@href='/docs/index']").not_nil!["href"]
    canonical_url = "#{Lucky::RouteHelper.settings.base_uri}#{next_path}"
    description = "第二篇文档：第二篇说明。"

    response.status_code.should eq(200)
    response.body.should_not contain("<!DOCTYPE")
    document.xpath_node("//header[@class='site-navbar'] | //*[@id='search_dialog']").should be_nil
    document.xpath_nodes("//*[@id='doc-content']").size.should eq(1)
    content.xpath_node(".//h1[@class='doc-page-title']").not_nil!.content.should eq("第二篇文档")
    content.content.should contain("第二篇独有正文")
    content.content.should_not contain("第一篇独有正文")
    content.xpath_node(".//*[@id='sidebar']//a[@class='active']").not_nil!["href"].should eq(next_path)
    document.xpath_nodes("//dialog[@id='comment-dialog']").size.should eq(1)
    content.xpath_node(".//footer").should_not be_nil
    form["data-draft-key"].should eq("#{user.id}:thread:#{child_thread.id}")
    URI.parse(comments["hx-get"]).query_params["comment_thread_id"].should eq(child_thread.id.to_s)
    document.xpath_node("//head").not_nil!["hx-head"].should eq("merge")
    document.xpath_node("//head/title").not_nil!.content.should eq("Crystal China - 第二篇文档")
    document.xpath_node("//head/link[@rel='canonical']").not_nil!["href"].should eq(canonical_url)
    document.xpath_node("//head/meta[@property='og:url']").not_nil!["content"].should eq(canonical_url)
    document.xpath_node("//head/meta[@name='description']").not_nil!["content"].should eq(description)
    document.xpath_node("//head/meta[@property='og:description']").not_nil!["content"].should eq(description)
    document.xpath_node("//head/meta[@name='twitter:description']").not_nil!["content"].should eq(description)
    document.xpath_nodes("//hx-partial").size.should eq(2)
    document.xpath_node("//hx-partial[@hx-target='#page-analytics']/div").not_nil!["data-page-title"].should eq("第二篇文档")
    document.xpath_node("//hx-partial[@hx-target='#notification-status']").should_not be_nil

    response = client.get("#{previous_path}?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    content = document.xpath_node("//div[@id='doc-content']").not_nil!
    first_doc = DocQuery.new.path_index(previous_path).first
    first_thread = CommentThreadQuery.new.doc_id(first_doc.id).first

    response.status_code.should eq(200)
    content.xpath_node(".//h1[@class='doc-page-title']").not_nil!.content.should eq("第一篇文档")
    content.content.should contain("第一篇独有正文")
    content.content.should_not contain("第二篇独有正文")
    content.xpath_node(".//*[@id='sidebar']//a[@class='active']").not_nil!["href"].should eq(previous_path)
    content.xpath_node(".//section[@id='form_with_comments']/form").not_nil!["data-draft-key"].should eq("#{user.id}:thread:#{first_thread.id}")
    document.xpath_node("//head/link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}#{previous_path}")
    first_doc.view_count.should eq(1)
    child_doc.view_count.should eq(1)

    {
      ApiClient.new,
      ApiClient.new.headers("HX-Request-Type": "full", "HX-History-Restore-Request": "true"),
    }.each do |full_page_client|
      response = full_page_client.get(next_path)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.body.should contain("<!DOCTYPE")
      document.xpath_node("//header[@class='site-navbar']").should_not be_nil
      document.xpath_node("//*[@id='doc-content']//h1[@class='doc-page-title']").not_nil!.content.should eq("第二篇文档")
      document.xpath_node("//head/link[@rel='canonical']").not_nil!["href"].should eq(canonical_url)
      document.xpath_node("//hx-partial").should be_nil
    end
  end

  it "keeps standalone documents free of the sidebar and pager, and supports guest partial responses" do
    {
      ApiClient.new,
      ApiClient.new.headers("HX-Request-Type": "partial"),
    }.each do |client|
      response = client.get("/docs/standalone")
      document = XML.parse_html(response.body)
      content = document.xpath_node("//div[@id='doc-content']").not_nil!

      response.status_code.should eq(200)
      content.xpath_node(".//h1[@class='doc-page-title']").not_nil!.content.should eq("独立文档")
      content.content.should contain("独立文档正文")
      content.xpath_node(".//aside | .//article/nav").should be_nil
      content.xpath_node(".//dialog[@id='comment-dialog']").should_not be_nil
      document.xpath_node("//header[@class='site-navbar'] | //*[@id='search_dialog']").should be_nil
      document.xpath_node("//hx-partial[@hx-target='#notification-status']").should be_nil
    end
  end
end
