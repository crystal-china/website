require "../spec_helper"
require "../../tasks/db/rebuild/content_html"

private def html_topic(author : User, content : String = "**hello**") : Topic
  node = SaveNode.create!(name: "HTML", slug: "stored-html", summary: "Stored body tests", color: "#16a34a", position: 0)

  CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Stored HTML", content: content)
end

private def assert_stored_html(record, source : String) : Nil
  record.content.should eq(source)
  record.content_html.should eq(UserMarkdown.render(source)[:html])
  record.content_html.not_nil!.should contain("<strong>hello</strong>")
  record.content_html.not_nil!.should contain(%(href="/users/a_b_c/profile"))
  record.content_html.not_nil!.should_not contain("onerror")
end

describe "Stored content HTML" do
  it "stores sanitized HTML and raw Markdown together for topics and comments" do
    user = UserFactory.create
    source = %(**hello** @a_b_c中文 <img src="image.png" onerror="alert(1)">)
    topic = html_topic(user, source)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: source)

    assert_stored_html(topic, source)
    assert_stored_html(comment, source)
  end

  it "writes paired HTML even when a stale topic's new Markdown produces the same HTML" do
    author = UserFactory.create
    original = html_topic(author)
    expected_html = original.content_html

    UpdateTopic.update!(original, content: "goodbye")
    saved = UpdateTopic.update!(original, content: "__hello__")

    saved.content.should eq("__hello__")
    saved.content_html.should eq(expected_html)
    TopicQuery.find(saved.id).content_html.should eq(expected_html)
  end

  it "writes paired HTML even when a stale comment's new Markdown produces the same HTML" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/stored-html")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    original = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "**hello**")
    expected_html = original.content_html

    UpdateComment.update!(original, content: "goodbye")
    saved = UpdateComment.update!(original, content: "__hello__")

    saved.content.should eq("__hello__")
    saved.content_html.should eq(expected_html)
    CommentQuery.find(saved.id).content_html.should eq(expected_html)
  end

  it "regenerates HTML on body edits but not on title changes, votes, deletion or restoration" do
    user = UserFactory.create
    topic = html_topic(user)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "**hello**")
    html = comment.content_html

    topic = UpdateTopic.update!(topic, title: "Changed title")
    topic.content_html.should eq(html)
    counts = comment.vote_counts
    counts.👍 = 1
    comment = UpdateCommentVoteCounts.update!(comment, vote_counts: counts)
    comment.content_html.should eq(html)
    comment.edited_at.should be_nil
    DeleteComment.delete!(comment)
    deleted = CommentQuery.new.only_soft_deleted.id(comment.id).first
    deleted.content_html.should eq(html)
    deleted.restore
    CommentQuery.find(comment.id).content_html.should eq(html)
    CommentQuery.find(comment.id).edited_at.should be_nil

    updated = UpdateComment.update!(comment, content: "**new body**")
    updated.content_html.not_nil!.should contain("<strong>new body</strong>")
    updated.edited_at.should_not be_nil
    topic = UpdateTopic.update!(topic, content: "**new topic**")
    topic.content_html.not_nil!.should contain("<strong>new topic</strong>")
  end

  it "stores empty generated HTML without treating it as missing" do
    user = UserFactory.create
    topic = html_topic(user, "[unused]: https://example.com")

    topic.content_html.should eq("")
    topic = UpdateTopic.update!(topic, content: "[changed]: https://example.org")
    topic.content_html.should eq("")
    TopicQuery.find(topic.id).content_html.should eq("")
  end

  it "does not report mention links inside raw HTML text containers" do
    ["script", "style", "textarea", "title"].each do |tag|
      rendered = UserMarkdown.render("text <#{tag}>@zw963</#{tag}>")

      rendered[:html].should_not contain(%(href="/users/zw963/profile"))
      rendered[:mentions].should be_empty
    end
  end

  it "reads stored HTML in topic pages, comment cards and RSS, with a legacy NULL fallback" do
    user = UserFactory.create
    topic = html_topic(user)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "**hello**")

    # Different stored bodies prove that these reads do not render the Markdown again.
    TopicQuery.new.id(topic.id).update(content_html: "<p>cached topic body</p>")
    CommentQuery.new.id(comment.id).update(content_html: "<p>cached comment body</p>")
    ApiClient.new.get("/forum/#{topic.id}").body.should contain("cached topic body")
    ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}").body.should contain("cached comment body")
    ApiClient.new.headers("Accept": "application/rss+xml").get("/forum/feed.xml").body.should contain("cached topic body")

    TopicQuery.new.id(topic.id).update(content_html: nil)
    CommentQuery.new.id(comment.id).update(content_html: nil)
    ApiClient.new.get("/forum/#{topic.id}").body.should contain("<strong>hello</strong>")
    ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}").body.should contain("<strong>hello</strong>")
  end

  it "rebuilds legacy and deleted records without changing timestamps, notifications or counters" do
    user = UserFactory.create
    topic = html_topic(user)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "**root**")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "**child**")
    DeleteComment.delete!(child)
    DeleteTopic.delete!(topic)
    topic = TopicQuery.new.only_soft_deleted.id(topic.id).first
    root = CommentQuery.find(root.id)
    child = CommentQuery.new.only_soft_deleted.id(child.id).first
    notifications_count = NotificationQuery.new.select_count

    TopicQuery.new.with_soft_deleted.id(topic.id).update(content_html: nil, updated_at: topic.updated_at)
    [root, child].each do |comment|
      CommentQuery.new.with_soft_deleted.id(comment.id).update(content_html: nil, updated_at: comment.updated_at)
    end

    2.times { Db::Rebuild::ContentHtml.new.call }

    rebuilt_topic = TopicQuery.new.with_soft_deleted.id(topic.id).first
    rebuilt_topic.content_html.should eq(UserMarkdown.render(topic.content)[:html])
    rebuilt_topic.updated_at.should eq(topic.updated_at)
    rebuilt_topic.edited_at.should eq(topic.edited_at)
    rebuilt_topic.soft_deleted_at.should eq(topic.soft_deleted_at)
    rebuilt_topic.replies_count.should eq(topic.replies_count)
    rebuilt_topic.last_active_at.should eq(topic.last_active_at)
    [root, child].each do |comment|
      rebuilt = CommentQuery.new.with_soft_deleted.id(comment.id).first

      rebuilt.content_html.should eq(UserMarkdown.render(comment.content)[:html])
      rebuilt.updated_at.should eq(comment.updated_at)
      rebuilt.edited_at.should eq(comment.edited_at)
      rebuilt.soft_deleted_at.should eq(comment.soft_deleted_at)
      rebuilt.floor.should eq(comment.floor)
      rebuilt.floor_counter.should eq(comment.floor_counter)
      rebuilt.children_count.should eq(comment.children_count)
      rebuilt.descendants_count.should eq(comment.descendants_count)
    end
    NotificationQuery.new.select_count.should eq(notifications_count)
  end
end
