require "../spec_helper"
require "../../tasks/db/fix/soft_delete_counts"

describe "Comment pagination counters" do
  it "counts kept roots on documents and topics across withdrawal, soft deletion, restoration, and physical deletion" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/pagination-counters", "文档正文")
    node = SaveNode.create!(name: "计数测试", slug: "comment-counters", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "评论计数", content: "主题正文")
    threads = [
      CommentThreadQuery.new.doc_id(doc.id).first,
      CommentThreadQuery.new.topic_id(topic.id).first,
    ]

    threads.each do |thread|
      thread.root_comments_count.should eq(0)
      root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")
      other_root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "other root")
      child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "child")
      CreateComment.create!(user_id: user.id, parent_id: child.id, content: "grandchild")

      CommentThreadQuery.find(thread.id).root_comments_count.should eq(2)
      CommentQuery.find(root.id).descendants_count.should eq(2)
      Comment::SaveOperation.update!(other_root, withdrawn: true)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(2)
      DeleteComment.delete!(other_root)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(1)

      # 物理删除已软删除的根评论不能再次递减。
      AppDatabase.exec("DELETE FROM comments WHERE id = $1", other_root.id)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(1)
      DeleteComment.delete!(root)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(0)
      CommentQuery.new.only_soft_deleted.id(root.id).first.restore
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(1)

      # 删除子评论及其后代，不影响评论区的根评论数量。
      AppDatabase.exec("DELETE FROM comments WHERE id = $1", child.id)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(1)
      CommentQuery.find(root.id).descendants_count.should eq(0)
      AppDatabase.exec("DELETE FROM comments WHERE id = $1", root.id)
      CommentThreadQuery.find(thread.id).root_comments_count.should eq(0)
    end
  end

  it "backfills existing records during migration and repairs counters without changing timestamps or notifications" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/counter-backfill", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "kept root")
    withdrawn_root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "withdrawn root")
    deleted_root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "deleted root")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "child")
    Comment::SaveOperation.update!(withdrawn_root, withdrawn: true)
    DeleteComment.delete!(deleted_root)
    notifications_count = NotificationQuery.new.select_count
    migration = AddRootCommentsCountToCommentThreads::V20261025120000.new

    # 删除字段后再迁移，模拟已有评论的生产数据库首次添加计数字段。
    migration.down(quiet: true)
    migration.up(quiet: true)

    CommentThreadQuery.find(thread.id).root_comments_count.should eq(2)
    CommentThreadQuery.find(thread.id).updated_at.should eq(thread.updated_at)
    AppDatabase.exec("UPDATE comment_threads SET root_comments_count = 99 WHERE id = $1", thread.id)
    AppDatabase.exec("UPDATE comments SET children_count = 99, descendants_count = 99 WHERE id = $1", root.id)
    Db::Fix::SoftDeleteCounts.new.call

    CommentThreadQuery.find(thread.id).root_comments_count.should eq(2)
    CommentThreadQuery.find(thread.id).updated_at.should eq(thread.updated_at)
    CommentQuery.find(root.id).children_count.should eq(1)
    CommentQuery.find(root.id).descendants_count.should eq(1)
    CommentQuery.find(root.id).updated_at.should eq(root.updated_at)
    CommentQuery.find(child.id).edited_at.should be_nil
    CommentQuery.new.only_soft_deleted.id(deleted_root.id).first.children_count.should eq(0)
    NotificationQuery.new.select_count.should eq(notifications_count)
  ensure
    migration.try(&.up(quiet: true)) if migration.try(&.pending?)
  end

  it "uses stored counts for root and reply pagination without issuing COUNT queries" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/counter-pagination", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    roots = Array.new(11) do |index|
      CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root #{index}")
    end

    12.times do |index|
      CreateComment.create!(user_id: user.id, parent_id: roots.first.id, content: "reply #{index}")
    end

    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    client = ApiClient.new

    {"comment_thread_id=#{thread.id}" => 1, "root_id=#{roots.first.id}" => 2}.each do |target, expected_size|
      Avram::Events::QueryEvent.logged_events.clear
      response = client.get("/htmx/comments?#{target}&page=2")
      queries = Avram::Events::QueryEvent.logged_events.map(&.query)

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_nodes("//article").size.should eq(expected_size)
      queries.any?(&.matches?(/\bCOUNT\s*\(/i)).should be_false
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end
end
