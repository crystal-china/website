require "../spec_helper"

describe "Deleted topic preview" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "trash-preview-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "previews deleted topics and paginated comments without restoring or modifying records" do
    admin = UserFactory.create &.email("trash-preview-admin@example.com")
    author = UserFactory.create
    node = SaveNode.create!(name: "预览测试", slug: "trash-preview", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "已删除主题预览", content: "**topic preview body**")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "**root preview body**")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "visible child preview")
    deleted_child = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "**deleted reply preview**")
    withdrawn = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "withdrawn original body")

    DeleteComment.delete!(deleted_child)
    Comment::SaveOperation.update!(withdrawn, withdrawn: true)

    extras = Array.new(17) do |index|
      CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "extra preview #{index}")
    end

    DeleteTopic.delete!(topic)

    topic = topic.reload
    comments_before = CommentQuery.new.with_soft_deleted.id.asc_order.results.map do |comment|
      {comment.id, comment.soft_deleted_at, comment.updated_at, comment.withdrawn?, comment.content, comment.content_html}
    end
    notifications_count = NotificationQuery.new.select_count
    client = ApiClient.new
    path = Admin::Trash::PreviewTopic.with(id: topic.id).path
    response = client.get("/admin/trash?kind=topics&backdoor_user_id=#{admin.id}")

    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_node("//section[@id='trash-list']//a[@href='#{path}']").should_not be_nil

    response = client.get("#{path}?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    preview = document.xpath_node("//section[@id='trash-topic-preview']").not_nil!
    comment_articles = preview.xpath_nodes("./article[starts-with(@id, 'comment-')]")

    response.status_code.should eq(200)
    preview.content.should contain("只读预览")
    preview.xpath_node("./article//strong").not_nil!.content.should eq("topic preview body")
    comment_articles.size.should eq(20)
    preview.xpath_node(".//article[@id='comment-#{root.id}']//strong").not_nil!.content.should eq("root preview body")
    preview.xpath_node(".//article[@id='comment-#{child.id}']").not_nil!.content.should contain("visible child preview")
    preview.xpath_node(".//article[@id='comment-#{deleted_child.id}']//strong").not_nil!.content.should eq("deleted reply preview")
    preview.xpath_node(".//article[@id='comment-#{deleted_child.id}']").not_nil!.content.should contain("删除于")
    preview.xpath_node(".//article[@id='comment-#{withdrawn.id}']").not_nil!.content.should contain("此评论内容已撤回")
    response.body.should_not contain("withdrawn original body")
    preview.xpath_nodes(".//form | .//button | .//*[@hx-post or @hx-put or @hx-patch or @hx-delete]").should be_empty
    next_path = preview.xpath_node("./nav/a").not_nil!["href"]

    response = client.get(next_path)
    preview = XML.parse_html(response.body).xpath_node("//section[@id='trash-topic-preview']").not_nil!

    response.status_code.should eq(200)
    preview.xpath_nodes("./article[starts-with(@id, 'comment-')]").size.should eq(1)
    preview.xpath_node("./article[@id='comment-#{extras.last.id}']").should_not be_nil
    reloaded_topic = topic.reload
    comments_after = CommentQuery.new.with_soft_deleted.id.asc_order.results.map do |comment|
      {comment.id, comment.soft_deleted_at, comment.updated_at, comment.withdrawn?, comment.content, comment.content_html}
    end

    reloaded_topic.soft_deleted_at.should eq(topic.soft_deleted_at)
    reloaded_topic.updated_at.should eq(topic.updated_at)
    reloaded_topic.replies_count.should eq(topic.replies_count)
    comments_after.should eq(comments_before)
    NotificationQuery.new.select_count.should eq(notifications_count)
    CommentQuery.new.publicly_visible_comments.any?.should be_false

    {"/forum/#{topic.id}", "/comments/#{child.id}", "/htmx/comments?comment_thread_id=#{thread.id}"}.each do |public_path|
      separator = public_path.includes?('?') ? '&' : '?'

      client.get("#{public_path}#{separator}backdoor_user_id=#{admin.id}").status_code.should eq(404)
    end
  end

  it "requires an administrator and a deleted topic, and translates the preview" do
    admin = UserFactory.create &.email("trash-preview-admin@example.com")
    author = UserFactory.create
    node = SaveNode.create!(name: "预览权限", slug: "trash-preview-permission", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Private preview", content: "private topic body")
    path = Admin::Trash::PreviewTopic.with(id: topic.id).path

    ApiClient.new.get("#{path}?backdoor_user_id=#{admin.id}").status_code.should eq(404)

    DeleteTopic.delete!(topic)

    ApiClient.new.headers("HX-Request-Type": "partial").get(path).status_code.should eq(401)
    response = ApiClient.new.get("#{path}?backdoor_user_id=#{author.id}")

    response.status_code.should eq(404)
    response.body.should_not contain("private topic body")
    ApiClient.new.headers("HX-Request-Type": "partial").get("#{path}?backdoor_user_id=#{author.id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash/topics/0/preview?backdoor_user_id=#{admin.id}").status_code.should eq(404)

    response = ApiClient.new.get("#{path}?locale=en&backdoor_user_id=#{admin.id}")
    preview = XML.parse_html(response.body).xpath_node("//section[@id='trash-topic-preview']").not_nil!

    response.status_code.should eq(200)
    preview.content.should contain("Read-only preview")
    preview.content.should contain("No comments on this topic.")
    preview.xpath_node("./header//a[@href='/admin/trash?kind=topics']").not_nil!.content.should eq("Back to trash")
  end
end
