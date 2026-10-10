require "../spec_helper"

describe CreateComment do
  it "rejects both comment targets on creation" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/save-reply-target")
    comment_thread_id = CommentThreadQuery.new.doc_id(doc.id).first.id
    parent = CreateComment.create!(user_id: user.id, comment_thread_id: comment_thread_id, content: "parent")

    CreateComment.create(user_id: user.id, comment_thread_id: comment_thread_id, parent_id: parent.id, content: "invalid") do |operation, comment|
      comment.should be_nil
      operation.not_nil!.errors[:comment_thread_id_or_parent_id].should contain("不能同时指定评论区和父评论")
    end
  end

  it "assigns floors independently within documents and comment threads" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/save-reply-floors")
    comment_thread_id = CommentThreadQuery.new.doc_id(doc.id).first.id
    first_root = CreateComment.create!(user_id: user.id, comment_thread_id: comment_thread_id, content: "first root")
    second_root = CreateComment.create!(user_id: user.id, comment_thread_id: comment_thread_id, content: "second root")
    first_child = CreateComment.create!(user_id: user.id, parent_id: first_root.id, content: "first child")
    second_child = CreateComment.create!(user_id: user.id, parent_id: first_child.id, content: "second child")

    {first_root.floor, second_root.floor}.should eq({1, 2})
    {first_child.floor, second_child.floor}.should eq({1, 2})
  end

  it "assigns unique floors to concurrent comments" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/concurrent-reply-floors")
    comment_thread_id = CommentThreadQuery.new.doc_id(doc.id).first.id
    results = Channel(Comment | Exception).new

    10.times do |index|
      spawn do
        results.send CreateComment.create!(user_id: user.id, comment_thread_id: comment_thread_id, content: "comment #{index}")
      rescue error
        results.send error
      end
    end

    comments = Array.new(10) { results.receive }
    errors = comments.select(Exception)
    errors.should be_empty
    comments.compact_map(&.as?(Comment)).map(&.floor).sort!.should eq((1..10).to_a)
  end
end
