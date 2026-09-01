require "../spec_helper"

describe SaveReply do
  it "requires exactly one reply target" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/save-reply-target")
    parent = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "parent")

    SaveReply.create(user_id: user.id, doc_id: doc.id, reply_id: parent.id, content: "invalid") do |operation, reply|
      reply.should be_nil
      operation.not_nil!.errors[:doc_id_or_reply_id].should contain("必须且只能有一个存在")
    end
  end

  it "assigns floors independently within documents and reply threads" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/save-reply-floors")
    first_root = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "first root")
    second_root = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "second root")
    first_child = SaveReply.create!(user_id: user.id, reply_id: first_root.id, content: "first child")
    second_child = SaveReply.create!(user_id: user.id, reply_id: first_child.id, content: "second child")

    {first_root.floor, second_root.floor}.should eq({1, 2})
    {first_child.floor, second_child.floor}.should eq({1, 2})
  end

  it "assigns unique floors to concurrent replies" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/concurrent-reply-floors")
    results = Channel(Reply | Exception).new

    10.times do |index|
      spawn do
        results.send SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "reply #{index}")
      rescue error
        results.send error
      end
    end

    replies = Array.new(10) { results.receive }
    errors = replies.select(Exception)
    errors.should be_empty
    replies.compact_map(&.as?(Reply)).map(&.floor).sort.should eq((1..10).to_a)
  end
end
