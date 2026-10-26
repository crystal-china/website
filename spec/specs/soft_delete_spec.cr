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
    doc = SaveDoc.create!(path_index: "/docs/soft-delete-spec", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "child")
    grandchild = CreateComment.create!(user_id: user.id, parent_id: child.id, content: "grandchild")

    DeleteComment.delete!(child)

    CommentQuery.new.id(child.id).first?.should be_nil
    CommentQuery.new.only_soft_deleted.id(child.id).first.id.should eq(child.id)
    CommentQuery.new.id(grandchild.id).first?.should_not be_nil
    CommentQuery.new.publicly_visible_comments.id.asc_order.map(&.id).should eq([root.id, grandchild.id])
    CommentQuery.find(root.id).descendants_count.should eq(1)
    CommentQuery.new.with_soft_deleted.id(child.id).first.children_count.should eq(1)
    ApiClient.new.get("/admin/trash?backdoor_user_id=#{user.id}").status_code.should eq(404)
    {"en" => "Deleted", "zh-CN" => "删除于"}.each do |locale, label|
      response = ApiClient.new.get("/admin/trash?locale=#{locale}&backdoor_user_id=#{admin.id}")
      deleted_at = CommentQuery.new.only_soft_deleted.id(child.id).first.soft_deleted_at.not_nil!
      time = XML.parse_html(response.body).xpath_node("//article//time").not_nil!

      response.status_code.should eq(200)
      time.content.should eq("#{label} #{deleted_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z")}")
      time["datetime"].should eq(deleted_at.to_rfc3339)
    end

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
    CommentQuery.new.publicly_visible_comments.any?.should be_false
    ApiClient.new.get("/htmx/comments?root_id=#{root.id}").status_code.should eq(404)

    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    CommentQuery.find(root.id).id.should eq(root.id)
    CommentQuery.new.publicly_visible_comments.id.asc_order.map(&.id).should eq([root.id, child.id, grandchild.id])
  end

  it "requires administrators to restore parents before their replies without changing rejected records" do
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    author = UserFactory.create
    node = SaveNode.create!(name: "恢复顺序", slug: "restore-parent-first", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "恢复顺序", content: "正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "子评论")
    grandchild = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "孙评论")

    [grandchild, child, root].each do |comment|
      DeleteComment.delete!(comment)
    end

    child = child.reload
    grandchild = grandchild.reload
    notifications_count = NotificationQuery.new.select_count
    client = ApiClient.new
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      {
        "zh-CN" => "不可恢复",
        "en"    => "Cannot restore this comment.",
      }.each do |locale, expected_message|
        Avram::Events::QueryEvent.logged_events.clear

        response = client.post("/admin/trash/comments/#{child.id}/restore?backdoor_user_id=#{admin.id}&locale=#{locale}")
        cookies = HTTP::Cookies.from_server_headers(response.headers)
        session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
        flash = JSON.parse(session.get(Lucky::FlashStore::SESSION_KEY))

        response.status_code.should eq(303)
        URI.parse(response.headers["Location"]).path.should eq("/admin/trash")
        flash["failure"].as_s.should eq(expected_message)
        flash["success"]?.should be_nil
        Avram::Events::QueryEvent.logged_events.none? { |event| event.query.includes?("FOR UPDATE") }.should be_true
        child.reload.soft_deleted_at.should eq(child.soft_deleted_at)
        child.reload.updated_at.should eq(child.updated_at)
        topic.reload.replies_count.should eq(0)
        thread.reload.root_comments_count.should eq(0)
        root.reload.descendants_count.should eq(0)
      end

      response = client.post("/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{author.id}")

      response.status_code.should eq(404)
      root.reload.soft_deleted?.should be_true
      client.post("/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)
      root.reload.soft_deleted?.should be_false
      topic.reload.replies_count.should eq(1)

      # 根评论存在也不够：直接父评论仍被删除时，不能越过它恢复孙评论。
      client.post("/admin/trash/comments/#{grandchild.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)
      grandchild.reload.soft_deleted_at.should eq(grandchild.soft_deleted_at)
      grandchild.reload.updated_at.should eq(grandchild.updated_at)
      topic.reload.replies_count.should eq(1)
      child.reload.children_count.should eq(0)

      client.post("/admin/trash/comments/#{child.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)
      client.post("/admin/trash/comments/#{grandchild.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)

      CommentQuery.new.publicly_visible_comments.id.asc_order.map(&.id).should eq([root.id, child.id, grandchild.id])
      root.reload.children_count.should eq(1)
      root.reload.descendants_count.should eq(2)
      child.reload.children_count.should eq(1)
      topic.reload.replies_count.should eq(3)
      NotificationQuery.new.select_count.should eq(notifications_count)
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end

  it "rejects restoring a reply when its root is deleted even if its direct parent still exists" do
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/restore-deleted-root", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "子评论")
    grandchild = CreateComment.create!(user_id: admin.id, parent_id: child.id, content: "孙评论")

    DeleteComment.delete!(grandchild)
    DeleteComment.delete!(root)

    grandchild = grandchild.reload

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.post("/admin/trash/comments/#{grandchild.id}/restore?backdoor_user_id=#{admin.id}&locale=zh-CN")
      cookies = HTTP::Cookies.from_server_headers(response.headers)
      session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
      flash = JSON.parse(session.get(Lucky::FlashStore::SESSION_KEY))

      response.status_code.should eq(303)
      flash["failure"].as_s.should eq("不可恢复")
      flash["success"]?.should be_nil
      grandchild.reload.soft_deleted_at.should eq(grandchild.soft_deleted_at)
      grandchild.reload.updated_at.should eq(grandchild.updated_at)
      root.reload.soft_deleted?.should be_true
      child.reload.soft_deleted?.should be_false
    end
  end

  it "hides and restores topics without deleting their comment threads" do
    user = UserFactory.create
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    node = SaveNode.create!(name: "测试", slug: "soft-delete-test", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "可恢复主题", content: "内容")
    thread_id = CommentThreadQuery.new.topic_id(topic.id).first.id
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread_id, content: "保留评论")

    DeleteTopic.delete!(topic)

    TopicQuery.new.id(topic.id).first?.should be_nil
    TopicQuery.new.only_soft_deleted.id(topic.id).first.id.should eq(topic.id)
    CommentThreadQuery.find(thread_id).target_visible?.should be_false
    CommentQuery.find(comment.id).content.should eq("保留评论")
    CommentQuery.new.publicly_visible_comments.any?.should be_false
    ApiClient.new.get("/forum/#{topic.id}").status_code.should eq(404)
    ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread_id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash?kind=topics&backdoor_user_id=#{user.id}").status_code.should eq(404)
    {"en" => "Deleted", "zh-CN" => "删除于"}.each do |locale, label|
      response = ApiClient.new.get("/admin/trash?kind=topics&locale=#{locale}&backdoor_user_id=#{admin.id}")
      deleted_at = TopicQuery.new.only_soft_deleted.id(topic.id).first.soft_deleted_at.not_nil!
      time = XML.parse_html(response.body).xpath_node("//article//time").not_nil!

      response.status_code.should eq(200)
      time.content.should eq("#{label} #{deleted_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z")}")
      time["datetime"].should eq(deleted_at.to_rfc3339)
    end

    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore

    TopicQuery.find(topic.id).id.should eq(topic.id)
    CommentThreadQuery.find(thread_id).target_visible?.should be_true
    CommentQuery.new.publicly_visible_comments.first.id.should eq(comment.id)
  end

  it "requires the topic to be restored before restoring its root comments or replies" do
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    author = UserFactory.create
    node = SaveNode.create!(name: "恢复主题优先", slug: "restore-topic-first", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "先恢复主题", content: "正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "存在的根评论")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "删除的子评论")
    other_root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "删除的根评论")

    DeleteComment.delete!(child)
    DeleteComment.delete!(other_root)
    DeleteTopic.delete!(topic)

    deleted_comments = [child.reload, other_root.reload]
    notifications_count = NotificationQuery.new.select_count
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      deleted_comments.each do |comment|
        response = client.post("/admin/trash/comments/#{comment.id}/restore?backdoor_user_id=#{admin.id}&locale=zh-CN")
        cookies = HTTP::Cookies.from_server_headers(response.headers)
        session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
        flash = JSON.parse(session.get(Lucky::FlashStore::SESSION_KEY))

        response.status_code.should eq(303)
        flash["failure"].as_s.should eq("不可恢复")
        flash["success"]?.should be_nil
        comment.reload.soft_deleted_at.should eq(comment.soft_deleted_at)
        comment.reload.updated_at.should eq(comment.updated_at)
      end

      topic.reload.soft_deleted?.should be_true
      topic.reload.replies_count.should eq(1)
      thread.reload.root_comments_count.should eq(1)
      root.reload.descendants_count.should eq(0)
      NotificationQuery.new.select_count.should eq(notifications_count)
      client.post("/admin/trash/topics/#{topic.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)

      deleted_comments.each do |comment|
        client.post("/admin/trash/comments/#{comment.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)
        comment.reload.soft_deleted?.should be_false
      end

      topic.reload.replies_count.should eq(3)
      CommentQuery.new.publicly_visible_comments.select_count.should eq(3)
    end
  end

  it "allows ordinary authors to delete comments from leaves upward" do
    author = UserFactory.create
    other = UserFactory.create
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/delete-child-counts", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: other.id, parent_id: root.id, content: "child")
    grandchild = CreateComment.create!(user_id: other.id, parent_id: child.id, content: "grandchild")
    leaf = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "leaf")
    client = ApiClient.new
    response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{author.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//button[@hx-delete='/htmx/comments/#{root.id}']").should be_nil
    document.xpath_node("//button[@hx-post='/htmx/comments/#{root.id}/withdraw']").should_not be_nil
    document.xpath_node("//button[@hx-delete='/htmx/comments/#{leaf.id}']").should_not be_nil
    response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{admin.id}")
    XML.parse_html(response.body).xpath_node("//button[@hx-post='/htmx/comments/#{root.id}/withdraw']").should_not be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{other.id}").status_code.should eq(403)
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
      client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{other.id}").status_code.should eq(409)
      client.delete("/htmx/comments/#{grandchild.id}?backdoor_user_id=#{other.id}").status_code.should eq(200)
      CommentQuery.find(child.id).children_count.should eq(0)
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
      client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{other.id}").status_code.should eq(200)
      CommentQuery.find(root.id).descendants_count.should eq(0)

      response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{author.id}")
      XML.parse_html(response.body).xpath_node("//button[@hx-delete='/htmx/comments/#{root.id}']").should_not be_nil
      client.delete("/htmx/comments/#{leaf.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
      CommentQuery.new.with_soft_deleted.id(root.id).first.children_count.should eq(0)
    end
  end

  it "renders authors' delete buttons without querying each comment's children" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/delete-button-queries", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    10.times { CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "comment") }
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    Avram::Events::QueryEvent.logged_events.clear

    response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{author.id}")
    queries = Avram::Events::QueryEvent.logged_events.map(&.query)

    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_nodes("//button[@hx-delete]").size.should eq(10)
    queries.any? { |sql| sql.starts_with?("SELECT 1") && sql.includes?("parent_id") }.should be_false

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      comment = CommentQuery.new.first
      Avram::Events::QueryEvent.logged_events.clear
      ApiClient.new.delete("/htmx/comments/#{comment.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
      queries = Avram::Events::QueryEvent.logged_events.map(&.query)
      queries.any? { |sql| sql.starts_with?("SELECT 1") && sql.includes?("parent_id") }.should be_false
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end

  it "keeps newly synced empty Markdown documents visible" do
    doc = DocContent.sync("/docs/empty-document", "")
    thread = CommentThreadQuery.new.doc_id(doc.id).first

    DocQuery.find(doc.id).content.should eq("")
    thread.target_visible?.should be_true
  end

  it "blocks votes on missing documents without changing existing votes, but allows empty documents" do
    user = UserFactory.create
    other = UserFactory.create
    doc = DocContent.sync("/docs/document-votes", "")
    path = "/htmx/vote?backdoor_user_id=#{user.id}"
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.patch(path, doc_id: doc.id, vote_type: "👍").status_code.should eq(200)
      vote = VoteQuery.new.doc_id(doc.id).first
      SaveDoc.update!(doc, content: nil)

      client.patch(path, doc_id: doc.id, vote_type: "👍").status_code.should eq(404)
      client.patch(path, doc_id: doc.id, vote_type: "👎").status_code.should eq(404)
      client.patch("/htmx/vote?backdoor_user_id=#{other.id}", doc_id: doc.id, vote_type: "👍").status_code.should eq(404)
      VoteQuery.new.doc_id(doc.id).map(&.id).should eq([vote.id])
      DocQuery.find(doc.id).vote_counts.👍.should eq(1)
      DocQuery.find(doc.id).vote_counts.👎.should eq(0)

      DocContent.sync(doc.path_index, "")

      client.patch(path, doc_id: doc.id, vote_type: "invalid").status_code.should eq(400)
      client.patch(path, doc_id: 0, vote_type: "👍").status_code.should eq(404)
      client.patch(path, doc_id: doc.id, vote_type: "👍").status_code.should eq(200)
      VoteQuery.new.doc_id(doc.id).any?.should be_false
      DocQuery.find(doc.id).vote_counts.👍.should eq(0)
    end
  end

  it "hides comments on missing documents and restores access when the source returns" do
    user = UserFactory.create
    admin = UserFactory.create &.email("soft-delete-admin@example.com")
    doc = DocContent.sync("/docs/missing-document", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "保留的子评论")
    auth = "backdoor_user_id=#{user.id}"
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(200)
      SaveDoc.update!(doc, content: nil)

      thread.target_visible?.should be_false
      CommentQuery.new.publicly_visible_comments.any?.should be_false
      client.get("/htmx/comments?comment_thread_id=#{thread.id}").status_code.should eq(404)
      client.get("/htmx/comments?root_id=#{root.id}").status_code.should eq(404)
      client.get("/comments/#{child.id}").status_code.should eq(404)
      client.get("/htmx/comments/new?id=#{child.id}&#{auth}").status_code.should eq(404)
      client.get("/htmx/comments/edit/#{child.id}?#{auth}").status_code.should eq(404)
      client.post("/htmx/comments?#{auth}", comment_thread_id: thread.id, content: "不能新增").status_code.should eq(404)
      client.post("/htmx/comments?#{auth}", id: child.id, op: "new", content: "不能回复").status_code.should eq(404)
      client.post("/htmx/comments?#{auth}", id: child.id, op: "edit", content: "不能编辑").status_code.should eq(404)
      client.delete("/htmx/comments/#{child.id}?#{auth}").status_code.should eq(404)
      client.post("/htmx/comments/#{child.id}/withdraw?#{auth}").status_code.should eq(404)
      client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(404)
      CommentQuery.new.select_count.should eq(2)
      CommentQuery.find(child.id).content.should eq(child.content)
      CommentQuery.find(child.id).vote_counts.👍.should eq(1)
      VoteQuery.new.comment_id(child.id).select_count.should eq(1)

      DeleteComment.delete!(root)

      deleted_root = root.reload
      response = client.post("/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}&locale=zh-CN")
      cookies = HTTP::Cookies.from_server_headers(response.headers)
      session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
      flash = JSON.parse(session.get(Lucky::FlashStore::SESSION_KEY))

      response.status_code.should eq(303)
      flash["failure"].as_s.should eq("不可恢复")
      flash["success"]?.should be_nil
      root.reload.soft_deleted_at.should eq(deleted_root.soft_deleted_at)
      root.reload.updated_at.should eq(deleted_root.updated_at)
      thread.reload.root_comments_count.should eq(0)
      client.get("/comments/#{child.id}").status_code.should eq(404)

      restored = DocContent.sync(doc.path_index, "")

      restored.id.should eq(doc.id)
      restored.content.should eq("")
      thread.target_visible?.should be_true
      root.reload.soft_deleted?.should be_true
      client.post("/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(303)
      CommentQuery.new.publicly_visible_comments.select_count.should eq(2)
      client.get("/comments/#{child.id}").status_code.should eq(303)
      client.get("/htmx/comments?root_id=#{root.id}").status_code.should eq(200)
      client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(200)
      VoteQuery.new.comment_id(child.id).any?.should be_false
    end
  end

  it "blocks comment reads and writes when the root or topic is deleted, without changing votes" do
    user = UserFactory.create
    node = SaveNode.create!(name: "可见性测试", slug: "comment-visibility", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "评论可见性", content: "内容")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: user.id, parent_id: root.id, content: "子评论")
    auth = "backdoor_user_id=#{user.id}"
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(200)

      [:root, :topic].each do |target|
        if target == :root
          DeleteComment.delete!(root)
        else
          DeleteTopic.delete!(topic)
        end

        client.get("/comments/#{child.id}").status_code.should eq(404)
        client.get("/htmx/comments/new?id=#{child.id}&#{auth}").status_code.should eq(404)
        client.get("/htmx/comments/edit/#{child.id}?#{auth}").status_code.should eq(404)
        client.post("/htmx/comments?#{auth}", id: child.id, op: "new", content: "不能回复").status_code.should eq(404)
        client.post("/htmx/comments?#{auth}", id: child.id, op: "edit", content: "不能编辑").status_code.should eq(404)
        client.delete("/htmx/comments/#{child.id}?#{auth}").status_code.should eq(404)
        client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(404)
        CommentQuery.new.with_soft_deleted.select_count.should eq(2)
        CommentQuery.find(child.id).content.should eq(child.content)
        CommentQuery.find(child.id).vote_counts.👍.should eq(1)
        VoteQuery.new.comment_id(child.id).select_count.should eq(1)

        if target == :root
          root = CommentQuery.new.only_soft_deleted.id(root.id).first.restore
        else
          topic = TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
        end

        client.get("/comments/#{child.id}").status_code.should eq(303)
      end

      client.patch("/htmx/vote?#{auth}", comment_id: child.id, vote_type: "👍").status_code.should eq(200)
      CommentQuery.find(child.id).vote_counts.👍.should eq(0)
      VoteQuery.new.comment_id(child.id).any?.should be_false
    end
  end
end
