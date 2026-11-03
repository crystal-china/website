require "../spec_helper"

private class CommentPreviewProbe < BaseComponent
  needs content : String
  needs preview_length : Int32 = 160

  def render : Nil
    render_full_comment_text = -> { para content }

    mount(
      Shared::CommentPreview,
      content: content,
      preview_length: preview_length,
      render_body: render_full_comment_text
    )
  end
end

describe Shared::CommentPreview do
  it "shows short comments directly, including the 160-character boundary" do
    ["", "中" * 80, "中" * 81, "中" * 160].each do |content|
      html = CommentPreviewProbe.new(content: content, current_user: nil).render_to_string
      document = XML.parse_html(html)

      document.xpath_node("//details").should be_nil
      document.xpath_node("//p").not_nil!.content.should eq(content)
    end
  end

  it "uses a native expand control and keeps escaped preview text separate from the complete body" do
    content = "中" * 160 + "\n<script>最后一段</script>"
    html = CommentPreviewProbe.new(content: content, current_user: nil).render_to_string
    document = XML.parse_html(html)
    details = document.xpath_node("//details").not_nil!

    details["open"]?.should be_nil
    details.xpath_nodes("./summary/span").size.should eq(2)
    details.xpath_node("./summary/span[1]").not_nil!.content.should eq("中" * 160 + "...")
    details.xpath_node("./p").not_nil!.content.should eq(content)
    document.xpath_nodes("//script | //button").should be_empty
  end

  it "uses an 80-character preview and folding threshold for trash comments" do
    [80, 81].each do |length|
      html = CommentPreviewProbe.new(
        content: "中" * length,
        preview_length: 80,
        current_user: nil
      ).render_to_string
      document = XML.parse_html(html)

      if length == 80
        document.xpath_node("//details").should be_nil
        document.xpath_node("//p").not_nil!.content.should eq("中" * 80)
      else
        details = document.xpath_node("//details").not_nil!

        details.xpath_node("./summary/span[1]").not_nil!.content.should eq("中" * 80 + "...")
        details.xpath_node("./p").not_nil!.content.should eq("中" * 81)
      end
    end
  end

  it "places the expand control in the existing comment header" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/comment-preview", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "中" * 161)
    response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}")
    document = XML.parse_html(response.body)
    summary = document.xpath_node("//details/summary").not_nil!

    response.status_code.should eq(200)
    summary.xpath_node("./header").should_not be_nil
    summary.xpath_nodes("./header//span[contains(@class, 'comment-preview-expand-label')]").size.should eq(1)
    summary.xpath_node("./span[contains(@class, 'comment-preview-expand-label')]").should be_nil

    author_info = summary.xpath_node("./header/div[contains(@class, 'comment-author')]").not_nil!

    author_info.xpath_node(".//a[contains(@class, 'user-name-stacked')]").should_not be_nil
    author_info.xpath_node(".//span[@class='user-name-nickname']").not_nil!.content.should eq(author.nickname)
    author_info.xpath_node(".//span[@class='user-name-login']").not_nil!.content.should eq("@#{author.login_name}")
    author_info.xpath_node(".//time").should be_nil
  end
end
