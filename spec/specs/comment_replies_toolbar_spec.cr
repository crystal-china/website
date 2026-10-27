require "../spec_helper"

describe "Comment replies toolbar" do
  it "keeps the toggle, count, and sort together without changing the main toolbar or load-more responses" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/replies-toolbar", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    replies = Array.new(12) do |index|
      CreateComment.create!(user_id: author.id, parent_id: root.id, content: "reply #{index}")
    end

    response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}")
    document = XML.parse_html(response.body)
    toggle = document.xpath_node("//div[@id='comment-#{root.id}-replies-toggle']").not_nil!
    expand = toggle.xpath_node("./button[not(@hidden)]").not_nil!

    response.status_code.should eq(200)
    expand.content.should contain("共 12 条回复")
    expand["hx-target"].should eq("#comment-#{root.id}-replies")
    toggle.xpath_node(".//a").should be_nil
    document.xpath_nodes("//a[@hx-target='#comments']").size.should eq(2)
    document.xpath_node("//*[@id='comments-count']").not_nil!.content.should eq("共 1 条回复")

    response = ApiClient.new.get(expand["hx-get"])
    document = XML.parse_html(response.body)
    toggle = document.xpath_node("//div[@id='comment-#{root.id}-replies-toggle']").not_nil!
    sort_links = toggle.xpath_nodes(".//a")
    collapse = toggle.xpath_node("./button[not(@hidden)]").not_nil!

    response.status_code.should eq(200)
    document.xpath_node("//div[@id='comment-#{root.id}-replies']").should_not be_nil
    document.xpath_node("//div[@id='comment-#{root.id}-body']").should be_nil
    document.xpath_node("//*[@id='comment-#{root.id}-replies-list-count']").should be_nil
    collapse.content.should eq("共 12 条回复")
    collapse["script"].should contain("add @hidden to #comment-#{root.id}-replies-sort")
    sort_links.map { |link| link["hx-target"] }.should eq(Array.new(2, "#comment-#{root.id}-replies"))

    response = ApiClient.new.get(sort_links.first["hx-get"])
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//div[@id='comment-#{root.id}-replies-toggle']/input").not_nil!["value"].should eq("asc")
    document.xpath_node("//div[@id='comment-#{root.id}-replies-sort']//a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("最早")
    document.xpath_nodes("//article").map(&.["id"]).should eq(replies.first(10).map { |reply| "comment-#{reply.id}" })

    load_more = document.xpath_node("//button[@hx-target='closest div'][@hx-get]").not_nil!
    response = ApiClient.new.get(load_more["hx-get"])
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//div[@id='comment-#{root.id}-replies-toggle']").should be_nil
    document.xpath_nodes("//article").map(&.["id"]).should eq(replies.last(2).map { |reply| "comment-#{reply.id}" })
  end
end
