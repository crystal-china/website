require "../spec_helper"

describe "Soft deletion" do
  around_each do |example|
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "soft-delete-admin@example.com"

    example.run
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "hides and restores comments without losing descendants or visible counts" do
    user = UserFactory.create
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/soft-delete-spec")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = SaveComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")
    child = SaveComment.create!(user_id: user.id, parent_id: root.id, content: "child")
    grandchild = SaveComment.create!(user_id: user.id, parent_id: child.id, content: "grandchild")

    DeleteComment.delete!(child)

    CommentQuery.new.id(child.id).first?.should be_nil
    CommentQuery.new.only_soft_deleted.id(child.id).first.id.should eq(child.id)
    CommentQuery.new.id(grandchild.id).first?.should_not be_nil
    CommentQuery.find(root.id).descendants_count.should eq(1)
    CommentQuery.new.with_soft_deleted.id(child.id).first.children_count.should eq(1)
    ApiClient.new.get("/admin/trash?backdoor_user_id=#{user.id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash?backdoor_user_id=#{admin.id}").status_code.should eq(200)

    thread_response = ApiClient.new.get("/htmx/comments?root_id=#{root.id}")
    thread_response.status_code.should eq(200)
    thread_response.body.should contain("回复已删除的评论")

    CommentQuery.new.only_soft_deleted.id(child.id).first.restore

    CommentQuery.find(child.id).id.should eq(child.id)
    CommentQuery.find(root.id).descendants_count.should eq(2)
    CommentQuery.find(root.id).children_count.should eq(1)

    DeleteComment.delete!(root)
    CommentQuery.new.id(root.id).first?.should be_nil
    CommentQuery.new.id(grandchild.id).first?.should_not be_nil
    ApiClient.new.get("/htmx/comments?root_id=#{root.id}").status_code.should eq(404)

    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    CommentQuery.find(root.id).id.should eq(root.id)
  end

  it "hides and restores topics without deleting their comment threads" do
    user = UserFactory.create
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    node = SaveNode.create!(name: "测试", slug: "soft-delete-test", summary: "测试", color: "#16a34a", position: 0)
    topic = SaveTopic.create!(user_id: user.id, node_id: node.id, title: "可恢复主题", content: "内容")
    thread_id = CommentThreadQuery.new.topic_id(topic.id).first.id
    comment = SaveComment.create!(user_id: user.id, comment_thread_id: thread_id, content: "保留评论")

    DeleteTopic.delete!(topic)

    TopicQuery.new.id(topic.id).first?.should be_nil
    TopicQuery.new.only_soft_deleted.id(topic.id).first.id.should eq(topic.id)
    CommentThreadQuery.find(thread_id).target_visible?.should be_false
    CommentQuery.find(comment.id).content.should eq("保留评论")
    ApiClient.new.get("/forum/#{topic.id}").status_code.should eq(404)
    ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread_id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash?kind=topics&backdoor_user_id=#{user.id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash?kind=topics&backdoor_user_id=#{admin.id}").status_code.should eq(200)

    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore

    TopicQuery.find(topic.id).id.should eq(topic.id)
    CommentThreadQuery.find(thread_id).target_visible?.should be_true
  end
end
