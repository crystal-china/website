require "../spec_helper"
require "../../tasks/db/rebuild/content_html"

private def wait_for_comment_lock : Nil
  deadline = Time.instant + 5.seconds
  loop do
    AppDatabase.exec("SELECT pg_stat_clear_snapshot()")
    waiting = AppDatabase.query_one(<<-SQL, as: Bool)
      SELECT EXISTS (
        SELECT 1 FROM pg_stat_activity
        WHERE datname = current_database() AND pid <> pg_backend_pid()
          AND wait_event_type = 'Lock' AND query LIKE '%FOR UPDATE%'
      )
      SQL
    return if waiting
    raise "Comment request did not wait for the row lock" if Time.instant >= deadline
    sleep 1.millisecond
  end
end

describe "Comment deletion and withdrawal" do
  around_each do |example|
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "comment-admin@example.com"
    example.run
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "withdraws a comment without hiding replies, changing counters, or allowing blank edits" do
    author = UserFactory.create
    other = UserFactory.create
    doc = DocContent.sync("/docs/withdraw-comment", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "private original body")
    reply = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "reply")
    notifications_count = NotificationQuery.new.select_count
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.patch("/htmx/vote?backdoor_user_id=#{other.id}", comment_id: child.id, vote_type: "👍").status_code.should eq(200)
      client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
      client.post("/htmx/comments/#{child.id}/withdraw?backdoor_user_id=#{other.id}").status_code.should eq(403)
      ApiClient.new.headers("HX-Request-Type": "partial").post("/htmx/comments/#{child.id}/withdraw").status_code.should eq(401)
      client.post("/htmx/comments/0/withdraw?backdoor_user_id=#{author.id}").status_code.should eq(404)

      response = client.post("/htmx/comments/#{child.id}/withdraw?backdoor_user_id=#{author.id}")
      document = XML.parse_html(response.body)
      withdrawn = CommentQuery.find(child.id)

      response.status_code.should eq(200)
      response.body.should contain("此评论内容已撤回")
      response.body.should_not contain("private original body")
      restore_button = document.xpath_node("//div[@id='comment-#{child.id}-body']//button[@hx-post='/htmx/comments/#{child.id}/restore']").not_nil!
      restore_button.content.should eq("恢复")
      restore_button["hx-swap"].should eq("outerHTML swap:1s")
      restore_button["hx-target"].should eq("#comment-#{child.id}-body")
      document.xpath_node("//article | //div[@id='comment-#{child.id}-comments']").should be_nil
      document.xpath_node("//header | //footer | //time | //img | //button[@hx-patch]").should be_nil
      {withdrawn.content, withdrawn.content_html}.should eq({child.content, child.content_html})
      withdrawn.withdrawn?.should be_true
      withdrawn.soft_deleted_at.should be_nil
      withdrawn.edited_at.should eq(child.edited_at)
      withdrawn.floor.should eq(child.floor)
      withdrawn.children_count.should eq(1)
      CommentQuery.find(root.id).descendants_count.should eq(2)
      NotificationQuery.new.select_count.should eq(notifications_count)
      client.get("/comments/#{child.id}").status_code.should eq(303)
      client.get("/comments/#{reply.id}").status_code.should eq(303)

      client.post("/htmx/comments/#{child.id}/withdraw?backdoor_user_id=#{author.id}").status_code.should eq(200)
      CommentQuery.find(child.id).edited_at.should eq(withdrawn.edited_at)
      client.patch("/htmx/vote?backdoor_user_id=#{other.id}", comment_id: child.id, vote_type: "👍").status_code.should eq(409)
      CommentQuery.find(child.id).vote_counts.👍.should eq(1)

      client.get("/htmx/comments/edit/#{child.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
      client.post("/htmx/comments?backdoor_user_id=#{author.id}", id: child.id, op: "edit", content: "changed while withdrawn").status_code.should eq(409)

      client.post("/htmx/comments/#{child.id}/restore?backdoor_user_id=#{other.id}").status_code.should eq(403)
      ApiClient.new.headers("HX-Request-Type": "partial").post("/htmx/comments/#{child.id}/restore").status_code.should eq(401)
      response = client.post("/htmx/comments/#{child.id}/restore?backdoor_user_id=#{author.id}", order_by: "asc")
      response.status_code.should eq(200)
      response.body.should contain("private original body")
      response.body.should contain("/htmx/vote")
      restored = CommentQuery.find(child.id)
      restored.withdrawn?.should be_false
      {restored.content, restored.content_html, restored.edited_at}.should eq({child.content, child.content_html, child.edited_at})
      restored.vote_counts.👍.should eq(1)
      NotificationQuery.new.select_count.should eq(notifications_count)

      client.post("/htmx/comments?backdoor_user_id=#{author.id}", id: child.id, op: "edit", content: " ").status_code.should eq(400)
      client.post("/htmx/comments?backdoor_user_id=#{author.id}", comment_thread_id: thread.id, content: " ").status_code.should eq(400)
      UpdateComment.update(withdrawn, content: "") do |operation, _|
        operation.saved?.should be_false
        operation.content.errors.should_not be_empty
      end

      client.post("/htmx/comments/#{child.id}/withdraw?backdoor_user_id=#{author.id}").status_code.should eq(200)
      # 删除最后一条直接回复后，撤回卡片同时显示“恢复”和“删除”。
      response = client.delete("/htmx/comments/#{reply.id}?backdoor_user_id=#{author.id}")
      response.status_code.should eq(200)
      document = XML.parse_html(response.body)
      document.xpath_node("//button[@hx-delete='/htmx/comments/#{child.id}'][@hx-target='#comment-#{root.id}-thread']").should_not be_nil
      document.xpath_node("//button[@hx-post='/htmx/comments/#{child.id}/restore']").should_not be_nil
      document.xpath_node("//button[@flow-id='comment-#{root.id}-collapse_thread'][not(@hidden)]").should_not be_nil
      CommentQuery.find(child.id).children_count.should eq(0)

      client.post("/htmx/comments/#{child.id}/restore?backdoor_user_id=#{author.id}").status_code.should eq(200)
      response = client.post("/htmx/comments?backdoor_user_id=#{author.id}", id: child.id, op: "edit", content: "new body")
      response.status_code.should eq(200)
      CommentQuery.find(child.id).withdrawn?.should be_false
      CommentQuery.find(child.id).content_html.should eq("<p>new body</p>\n")
      CommentQuery.new.root_id(root.id).select_count.should eq(1)

      client.post("/htmx/comments/#{child.id}/withdraw?backdoor_user_id=#{author.id}").status_code.should eq(200)
      client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
      CommentQuery.find(root.id).descendants_count.should eq(0)
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
    end
  end

  it "keeps withdrawal visible and counted in topic pages, profile replies, and HTML rebuilds" do
    author = UserFactory.create
    admin = UserFactory.create &.email("comment-admin@example.com")
    node = SaveNode.create!(name: "撤回测试", slug: "withdraw", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "撤回测试", content: "topic")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "original")
    reply = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "reply")
    activity = TopicQuery.find(topic.id)
    notifications_count = NotificationQuery.new.select_count
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.post("/htmx/comments/#{root.id}/withdraw?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      CommentQuery.find(root.id).withdrawn?.should be_true
      client.post("/htmx/comments/#{root.id}/restore?backdoor_user_id=#{author.id}").status_code.should eq(200)
      CommentQuery.find(root.id).withdrawn?.should be_false
      response = client.post("/htmx/comments/#{root.id}/withdraw?backdoor_user_id=#{author.id}&locale=en", comment: {actor_id: admin.id})

      response.status_code.should eq(200)
      response.body.should contain("This comment has been withdrawn")

      document = XML.parse_html(response.body)

      document.xpath_node("//div[@id='comment-#{root.id}-body']").should_not be_nil
      document.xpath_node("//article | //div[@id='comment-#{root.id}-comments']").should be_nil
      document.xpath_node("//div[@id='comment-#{root.id}-thread-toggle'] | //*[@hx-preserve]").should be_nil

      response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{admin.id}")
      XML.parse_html(response.body).xpath_node("//button[@hx-post='/htmx/comments/#{root.id}/restore']").should_not be_nil
      client.post("/htmx/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      CommentQuery.find(root.id).withdrawn?.should be_false
      client.post("/htmx/comments/#{root.id}/withdraw?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      CommentQuery.find(root.id).withdrawn?.should be_true
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{admin.id}").status_code.should eq(409)

      # 管理员仍然可以撤回、恢复自己的评论，但不因此产生管理通知。
      client.post("/htmx/comments/#{reply.id}/withdraw?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      CommentQuery.find(reply.id).withdrawn?.should be_true
      client.post("/htmx/comments/#{reply.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      CommentQuery.find(reply.id).withdrawn?.should be_false
      NotificationQuery.new.select_count.should eq(notifications_count)
    end

    rebuilt_activity = TopicQuery.find(topic.id)
    rebuilt_activity.replies_count.should eq(activity.replies_count)
    rebuilt_activity.last_active_at.should eq(activity.last_active_at)
    rebuilt_activity.last_reply_user_id.should eq(activity.last_reply_user_id)
    2.times { Db::Rebuild::ContentHtml.new.call }
    CommentQuery.find(root.id).content_html.should eq(root.content_html)
    response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}")
    response.body.should contain("此评论内容已撤回")
    document = XML.parse_html(response.body)
    document.xpath_node("//article[@id='comment-#{root.id}']/div[@id='comment-#{root.id}-body'][@class='comment-withdrawn']").should_not be_nil
    document.xpath_node("//article[@id='comment-#{root.id}']/div[@class='comment-thread']/div[@id='comment-#{root.id}-comments']").should_not be_nil
    document.xpath_node("//article[@id='comment-#{root.id}']/div[@class='comment-thread']/div[@id='comment-#{root.id}-thread-toggle']").should_not be_nil
    document.xpath_node("//div[@id='comment-#{root.id}-body']//div[@id='comment-#{root.id}-thread-toggle']").should be_nil
    document.xpath_node("//button[@flow-id='comment-#{root.id}-load_thread'][not(@hidden)]").should_not be_nil
    document.xpath_node("//button[@flow-id='comment-#{root.id}-collapse_thread'][@hidden]").should_not be_nil
    document.xpath_node("//button[@hx-post='/htmx/comments/#{root.id}/restore']").should be_nil
    profile = ApiClient.new.get("/users/#{author.login_name}/profile?show_replies=true")
    profile.body.should contain("此评论内容已撤回")
    profile.body.should_not contain("original")

    DeleteTopic.delete!(topic)
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.post("/htmx/comments/#{root.id}/withdraw?backdoor_user_id=#{author.id}").status_code.should eq(404)
      client.post("/htmx/comments/#{root.id}/restore?backdoor_user_id=#{author.id}").status_code.should eq(404)
    end
  end

  it "replaces the whole thread when the first reply is created and the last reply is deleted" do
    author = UserFactory.create
    doc = DocContent.sync("/docs/thread-toggle", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    client = ApiClient.new

    response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&backdoor_user_id=#{author.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//div[@id='comment-#{root.id}-thread-toggle'][@class='hidden']").should_not be_nil

    response = client.get("/htmx/comments/new?id=#{root.id}&backdoor_user_id=#{author.id}")
    XML.parse_html(response.body).xpath_node("//form[@hx-target='#comment-#{root.id}-thread']").should_not be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post("/htmx/comments?backdoor_user_id=#{author.id}", id: root.id, op: "new", content: "first reply")
      document = XML.parse_html(response.body)
      child = CommentQuery.new.parent_id(root.id).first

      response.status_code.should eq(200)
      document.xpath_node("//div[@id='comment-#{root.id}-thread']/div[@id='comment-#{root.id}-thread-toggle']//button[@flow-id='comment-#{root.id}-collapse_thread'][not(@hidden)]").should_not be_nil
      document.xpath_node("//div[@id='comment-#{root.id}-thread']/div[@id='comment-#{root.id}-comments']//article[@id='comment-#{child.id}']").should_not be_nil
      document.xpath_node("//hx-partial[@hx-target='#comment-#{root.id}-thread-toggle']").should be_nil
      document.xpath_node("//hx-partial[@hx-target='#comment-#{root.id}-controls']//button[@hx-post='/htmx/comments/#{root.id}/withdraw']").should_not be_nil

      response = client.get("/htmx/comments/new?id=#{child.id}&backdoor_user_id=#{author.id}")
      XML.parse_html(response.body).xpath_node("//form[@hx-target='#comment-#{root.id}-thread']").should_not be_nil

      response = client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{author.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//div[@id='comment-#{root.id}-thread']/div[@id='comment-#{root.id}-thread-toggle'][@class='hidden']").should_not be_nil
      document.xpath_node("//div[@id='comment-#{root.id}-thread']/div[@id='comment-#{root.id}-comments']").not_nil!.children.should be_empty
      document.xpath_node("//hx-partial[@hx-target='#comment-#{root.id}-thread-toggle']").should be_nil
      document.xpath_node("//hx-partial[@hx-target='#comment-#{root.id}-controls']//button[@hx-delete='/htmx/comments/#{root.id}']").should_not be_nil
    end
  end

  it "locates withdrawn roots and replies on later pages without exposing their original bodies" do
    author = UserFactory.create
    doc = DocContent.sync("/docs/withdraw-focus", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "hidden root body")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "hidden child body")
    notification = SaveNotification.create!(
      user_id: author.id,
      actor_id: author.id,
      kind: :mention,
      url: "/comments/#{child.id}",
      source_title: "Before withdrawal",
      excerpt: "Historical excerpt"
    )
    11.times do
      CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "newer root")
      CreateComment.create!(user_id: author.id, parent_id: root.id, content: "newer reply")
    end
    Comment::SaveOperation.update!(root, withdrawn: true)
    Comment::SaveOperation.update!(child, withdrawn: true)
    client = ApiClient.new

    response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&comment_id=#{root.id}")
    document = XML.parse_html(response.body)
    card = document.xpath_node("//article[@id='comment-#{root.id}']").not_nil!
    card["script"].should contain("comment-focused")
    card.content.should contain("此评论内容已撤回")
    document.xpath_nodes("//article[@script]").size.should eq(1)
    response.body.should_not contain("hidden root body")

    response = client.get("/htmx/comments?comment_thread_id=#{thread.id}&comment_id=#{child.id}")
    document = XML.parse_html(response.body)
    document.xpath_node("//div[@id='comment-#{root.id}-comments'][@hx-trigger='load']").not_nil!["hx-get"].should contain("comment_id=#{child.id}")
    document.xpath_node("//button[@flow-id='comment-#{root.id}-collapse_thread'][not(@hidden)]").should_not be_nil
    document.xpath_nodes("//div[@hx-trigger='load']").size.should eq(1)
    document.xpath_nodes("//article[@script]").should be_empty

    response = client.get("/htmx/comments?root_id=#{root.id}&comment_id=#{child.id}")
    document = XML.parse_html(response.body)
    document.xpath_node("//article[@id='comment-#{child.id}']").not_nil!["script"].should contain("comment-focused")
    document.xpath_nodes("//article[@script]").size.should eq(1)
    response.body.should_not contain("hidden child body")
    client.get("/comments/#{child.id}").headers["Location"].should contain("comment_id=#{child.id}")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post("/notifications/#{notification.id}/read?backdoor_user_id=#{author.id}")
      response.headers["Location"].should eq("/comments/#{child.id}")
      NotificationQuery.find(notification.id).read_at.should_not be_nil
      NotificationQuery.find(notification.id).excerpt.should eq("Historical excerpt")
    end
  end

  it "checks all descendants for roots but only direct replies for child comments" do
    author = UserFactory.create
    doc = DocContent.sync("/docs/removal-counters", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "A")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "B")
    middle = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "C")
    descendant = CreateComment.create!(user_id: author.id, parent_id: middle.id, content: "D")
    # 仅用于验证不同统计范围；新的 HTTP 接口不会允许删除仍有回复的 C。
    DeleteComment.delete!(middle)

    CommentQuery.find(child.id).deletable?.should be_true
    CommentQuery.find(root.id).deletable?.should be_false
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client = ApiClient.new
      client.delete("/htmx/comments/#{child.id}?backdoor_user_id=#{author.id}").status_code.should eq(200)
      CommentQuery.find(root.id).children_count.should eq(0)
      CommentQuery.find(root.id).descendants_count.should eq(1)
      client.get("/comments/#{descendant.id}").status_code.should eq(303)
      client.delete("/htmx/comments/#{root.id}?backdoor_user_id=#{author.id}").status_code.should eq(409)
    end
  end

  it "serializes replies and deletion so a deleted parent cannot acquire a new reply" do
    author = UserFactory.create
    doc = DocContent.sync("/docs/removal-locks", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    parent = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "parent")
    results = Channel(HTTP::Client::Response | Exception).new(1)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      # 回复先持有锁：等待的删除请求必须读到更新后的计数，拒绝删除。
      AppDatabase.transaction do
        CommentQuery.new.id(root.id).for_update.first
        CommentQuery.new.id(parent.id).for_update.first
        spawn do
          results.send ApiClient.new.delete("/htmx/comments/#{parent.id}?backdoor_user_id=#{author.id}")
        rescue error
          results.send error
        end
        wait_for_comment_lock
        CreateComment.create!(user_id: author.id, parent_id: parent.id, content: "new reply")
      end
      response = results.receive
      response.should be_a(HTTP::Client::Response)
      response.as(HTTP::Client::Response).status_code.should eq(409)
      CommentQuery.find(parent.id).children_count.should eq(1)

      leaf = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "leaf")
      # 删除先持有锁：即使回复请求之前通过了检查，加锁后也必须重新检查。
      AppDatabase.transaction do
        CommentQuery.new.id(root.id).for_update.first
        CommentQuery.new.id(leaf.id).for_update.first
        spawn do
          results.send ApiClient.new.post("/htmx/comments?backdoor_user_id=#{author.id}", id: leaf.id, op: "new", content: "too late")
        rescue error
          results.send error
        end
        wait_for_comment_lock
        DeleteComment.delete!(leaf)
      end
      response = results.receive
      response.should be_a(HTTP::Client::Response)
      response.as(HTTP::Client::Response).status_code.should eq(404)
      CommentQuery.new.parent_id(leaf.id).any?.should be_false
    end
  end
end
