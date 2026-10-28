require "../spec_helper"
require "timecop"

describe "Trash comment relations" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "trash-relations-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "links only deleted parents outside the batch and groups exact deletion times within the same comment thread" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/trash-relations", content: "正文")
    other_doc = SaveDoc.create!(path_index: "/docs/trash-other-thread", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    other_thread = CommentThreadQuery.new.doc_id(other_doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "child")
    grandchild = CreateComment.create!(user_id: admin.id, parent_id: child.id, content: "grandchild")
    old_child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "previous deletion")
    other = CreateComment.create!(user_id: admin.id, comment_thread_id: other_thread.id, content: "other thread")
    at = Time.utc(2026, 10, 26, 12, 0, 0, nanosecond: 123456000)

    Timecop.freeze(at - 1.microsecond) { DeleteComment.delete!(old_child) }
    Timecop.freeze(at) do
      DeleteComment.delete!(root, delete_descendants: true)
      DeleteComment.delete!(other)
    end

    notifications_count = NotificationQuery.new.select_count
    response = ApiClient.new.get("/admin/trash?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    card = document.xpath_node("//article[@id='trash-comment-#{grandchild.id}']").not_nil!
    batch_button = document.xpath_node("//div[@id='trash-comment-#{grandchild.id}-group']//button[@hx-get]").not_nil!

    response.status_code.should eq(200)
    document.xpath_nodes("//article").map(&.["id"]).should eq(
      [other, grandchild, old_child].map { |comment| "trash-comment-#{comment.id}" }
    )
    batch_button["hx-push-url"].should eq("false")
    batch_button["hx-target"].should eq("#trash-comment-#{grandchild.id}-replies-list")
    restore_form = card.xpath_node(".//form").not_nil!

    restore_form["script"].should contain("on trash:comment:restored")
    restore_form["hx-target"].should eq("#page-flash")
    restore_form["hx-swap"].should eq("innerHTML show:none")
    restore_form["hx-push-url"].should eq("false")
    document.xpath_node("//article[@id='trash-comment-#{old_child.id}']//button[@hx-get]").should be_nil
    document.xpath_node("//article[@id='trash-comment-#{other.id}']//button[@hx-get]").should be_nil
    card.content.should_not contain("回复评论 ##{child.id}")
    card.xpath_nodes(".//a[contains(@href, '/admin/trash/comments/')]").should be_empty

    old_child_card = document.xpath_node("//article[@id='trash-comment-#{old_child.id}']").not_nil!
    parent_link = old_child_card.xpath_node(".//span[time]/a[.='父评论 ##{root.id}']").not_nil!

    parent_link["href"].should eq(Admin::Trash::ShowComment.with(id: root.id).path)

    inline_response = ApiClient.new.headers("HX-Request-Type": "partial").get("#{batch_button["hx-get"]}&backdoor_user_id=#{admin.id}")
    inline_document = XML.parse_html(inline_response.body)

    inline_response.status_code.should eq(200)
    inline_document.xpath_node("//div[@id='trash-comment-#{grandchild.id}-replies-list']").should_not be_nil
    inline_document.xpath_nodes("//article").map(&.["id"]).should eq(
      [child, root].map { |comment| "trash-comment-#{comment.id}" }
    )
    displayed_ids = document.xpath_nodes("//article").map(&.["id"]) + inline_document.xpath_nodes("//article").map(&.["id"])

    displayed_ids.uniq.size.should eq(5)
    inline_document.xpath_nodes("//button[@hx-get] | //main | //header").should be_empty
    inline_document.content.should contain("同批其他评论（2 条）")
    inline_document.content.should_not contain("回复评论 ##{root.id}")
    inline_document.xpath_nodes("//a[contains(@href, '/admin/trash/comments/')]").should be_empty

    Time.parse_rfc3339(URI.parse(batch_button["hx-get"]).query_params["deleted_at"]).should eq(at)
    inline_document.content.should contain("请先恢复父评论，再恢复子评论。")
    NotificationQuery.new.select_count.should eq(notifications_count)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      restore_child = inline_document.xpath_node("//article[@id='trash-comment-#{child.id}']//form").not_nil!["action"]
      response = ApiClient.new.post("#{restore_child}?backdoor_user_id=#{admin.id}")

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.body.should contain("不可恢复")
      child.reload.soft_deleted?.should be_true

      restore_root = inline_document.xpath_node("//article[@id='trash-comment-#{root.id}']//form").not_nil!["action"]
      response = ApiClient.new.post("#{restore_root}?backdoor_user_id=#{admin.id}")

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      root.reload.soft_deleted?.should be_false
      child.reload.soft_deleted?.should be_true
      response = ApiClient.new.get("#{batch_button["hx-get"]}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)
      child_card = document.xpath_node("//article[@id='trash-comment-#{child.id}']").not_nil!

      document.xpath_nodes("//article").size.should eq(1)
      document.content.should contain("同批其他评论（1 条）")
      child_card.content.should_not contain("回复评论 ##{root.id}")
      document.xpath_nodes("//a[contains(@href, '/admin/trash/comments/')]").should be_empty
      old_child.reload.soft_deleted_at.should eq(at - 1.microsecond)
    end
  end

  it "updates restore results without navigating or replacing the list" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/trash-restore-flash", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "child")

    DeleteComment.delete!(root, delete_descendants: true)

    path = Admin::Trash::RestoreComment.with(id: child.id).path

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      ["full", "partial"].each do |request_type|
        response = ApiClient.new.headers("HX-Request-Type": request_type).post("#{path}?backdoor_user_id=#{admin.id}")
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        response.headers["Location"]?.should be_nil
        response.headers["HX-Retarget"]?.should be_nil
        response.headers["HX-Reswap"]?.should be_nil
        response.headers["HX-Push-Url"]?.should be_nil
        document.xpath_node("//div[contains(@class, 'flash-message--failure')]").not_nil!.content.should eq("不可恢复")
        document.xpath_nodes("//main | //article | //section[@id='trash-list']").should be_empty
        response.headers["HX-Trigger"]?.should be_nil
        child.reload.soft_deleted?.should be_true
      end

      response = ApiClient.new.headers("HX-Request-Type": "full").post(
        "/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}"
      )

      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.headers["HX-Retarget"]?.should be_nil
      response.headers["HX-Reswap"]?.should be_nil
      response.headers["HX-Push-Url"]?.should be_nil
      document.xpath_node("//div[contains(@class, 'flash-message--success')]").not_nil!.content.should eq("评论已恢复")
      JSON.parse(response.headers["HX-Trigger"])["trash:comment:restored"]["batch_empty"].as_bool.should be_false
      document.xpath_nodes("//hx-partial | //main | //article").should be_empty
      root.reload.soft_deleted?.should be_false
    end
  end

  it "only removes the whole batch after every member has been restored" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/trash-restore-siblings", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "root")
    first_child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "first child")
    last_child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "last child")

    DeleteComment.delete!(root, delete_descendants: true)

    deleted_at = last_child.reload.soft_deleted_at.not_nil!

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      {root => false, last_child => false, first_child => true}.each do |comment, batch_empty|
        response = ApiClient.new.post("/admin/trash/comments/#{comment.id}/restore?backdoor_user_id=#{admin.id}")

        response.status_code.should eq(200)
        JSON.parse(response.headers["HX-Trigger"])["trash:comment:restored"]["batch_empty"].as_bool.should eq(batch_empty)
      end
    end

    path = Admin::Trash::BatchComments.with(id: last_child.id, deleted_at: deleted_at.to_rfc3339(fraction_digits: 6)).path
    response = ApiClient.new.get("#{path}&backdoor_user_id=#{admin.id}")

    XML.parse_html(response.body).xpath_nodes("//article").should be_empty
  end

  it "finds batch peers outside the current page or keyword matches and hides the link for the last deleted member" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/trash-batch-peers", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "search target")
    child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "remaining member")
    at = Time.utc

    Timecop.freeze(at) { DeleteComment.delete!(root, delete_descendants: true) }

    20.times do |index|
      comment = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "separate deletion #{index}")

      Timecop.freeze(at + (index + 1).seconds) { DeleteComment.delete!(comment) }
    end

    [
      Admin::Trash::Index.with(page: 2).path,
      Admin::Trash::Index.with(q: root.content).path,
    ].each do |path|
      response = ApiClient.new.headers("HX-Request-Type": "partial").get("#{path}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//article").size.should eq(1)
      document.xpath_node("//article").not_nil!["id"].should eq("trash-comment-#{child.id}")
      document.xpath_node("//div[@id='trash-comment-#{child.id}-group']//button[@hx-get]").should_not be_nil
    end

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      ApiClient.new.post("/admin/trash/comments/#{root.id}/restore?backdoor_user_id=#{admin.id}").status_code.should eq(200)
    end

    path = Admin::Trash::Index.with(q: child.content).path
    response = ApiClient.new.get("#{path}&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_nodes("//article").size.should eq(1)
    document.xpath_node("//article//button[@hx-get]").should be_nil
  end

  it "paginates a deletion batch and locates ancestors on their correct global trash page" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/trash-batch-pages", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "root")
    replies = Array.new(21) do |index|
      CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "reply #{index}")
    end

    DeleteComment.delete!(root, delete_descendants: true)

    deleted_at = root.reload.soft_deleted_at.not_nil!

    20.times do |index|
      comment = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "another batch #{index}")

      Timecop.freeze(deleted_at + (index + 1).seconds) { DeleteComment.delete!(comment) }
    end

    path = Admin::Trash::Index.path
    response = ApiClient.new.get("#{path}?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    next_path = document.xpath_node("//section[@id='trash-list']/div/nav/a").not_nil!["href"]

    document.xpath_nodes("//section[@id='trash-list']//article").size.should eq(20)
    response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main").should be_nil
    document.xpath_nodes("//section[@id='trash-list']//article").map(&.["id"]).should eq(
      ["trash-comment-#{replies.last.id}"]
    )

    inline_path = Admin::Trash::BatchComments.with(
      id: replies.last.id,
      deleted_at: deleted_at.to_rfc3339(fraction_digits: 6)
    ).path
    response = ApiClient.new.get("#{inline_path}&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    pagination = document.xpath_node("//div[nav]").not_nil!
    next_path = pagination.xpath_node("./nav/a").not_nil!["href"]

    document.xpath_nodes("//article").size.should eq(20)
    document.xpath_nodes("//article").map(&.["id"]).should eq(
      replies[0...-1].reverse.map { |comment| "trash-comment-#{comment.id}" }
    )
    document.xpath_nodes("//button[@hx-get]").should be_empty
    pagination["hx-push-url:inherited"].should eq("false")
    pagination["hx-target:inherited"].should eq("#trash-comment-#{replies.last.id}-replies-list")
    response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_nodes("//article").map(&.["id"]).should eq(["trash-comment-#{root.id}"])

    response = ApiClient.new.get("#{Admin::Trash::ShowComment.with(id: root.id).path}?backdoor_user_id=#{admin.id}")

    response.status_code.should eq(303)

    location = response.headers["Location"]

    URI.parse(location).query_params["page"].should eq("2")
    response = ApiClient.new.get("#{location}&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    batch_button = document.xpath_node("//div[@id='trash-comment-#{replies.last.id}-group']//button[@hx-get]").not_nil!

    response.status_code.should eq(200)
    document.xpath_node("//article[@id='trash-comment-#{root.id}']").should be_nil
    batch_button["hx-trigger"].should eq("load, click")
    response = ApiClient.new.get("#{batch_button["hx-get"]}&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    target = document.xpath_node("//article[@id='trash-comment-#{root.id}']").not_nil!

    response.status_code.should eq(200)
    target["script"].should contain("scroll to the middle of me")
    target["class"].should contain("bg-amber-50")
    document.xpath_nodes("//article[@script]").size.should eq(1)
    previous_page = document.xpath_node("//nav/a").not_nil!["href"]
    response = ApiClient.new.get(previous_page)

    XML.parse_html(response.body).xpath_nodes("//article").size.should eq(20)
    root.reload.soft_deleted?.should be_true
  end

  it "redirects kept ancestors to their public entry without exposing trash to ordinary users" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/trash-kept-ancestor", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")
    path = Admin::Trash::ShowComment.with(id: root.id).path
    response = ApiClient.new.get("#{path}?backdoor_user_id=#{admin.id}")

    response.status_code.should eq(303)
    response.headers["Location"].should eq(Comments::Show.with(id: root.id).path)
    ApiClient.new.get("#{path}?backdoor_user_id=#{user.id}").status_code.should eq(404)
    response = ApiClient.new.get(path)

    response.status_code.should eq(303)
    response.headers["Location"].should eq(SignIns::New.path)
    ApiClient.new.headers("HX-Request-Type": "partial").get(path).status_code.should eq(401)
    ApiClient.new.get("/admin/trash/comments/0?backdoor_user_id=#{admin.id}").status_code.should eq(404)

    batch_path = Admin::Trash::BatchComments.with(id: root.id, deleted_at: Time.utc.to_rfc3339).path

    ApiClient.new.get("#{batch_path}&backdoor_user_id=#{user.id}").status_code.should eq(404)
    ApiClient.new.headers("HX-Request-Type": "partial").get(batch_path).status_code.should eq(401)
    ApiClient.new.get("/admin/trash/comments/#{root.id}/batch?deleted_at=invalid&backdoor_user_id=#{admin.id}").status_code.should eq(400)
  end

  it "translates inline batch controls and rejects invalid batch dates" do
    admin = UserFactory.create &.email("trash-relations-admin@example.com")
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/trash-translations", content: "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: admin.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: admin.id, parent_id: root.id, content: "child")

    DeleteComment.delete!(root, delete_descendants: true)

    path = Admin::Trash::BatchComments.with(
      id: child.id,
      deleted_at: child.reload.soft_deleted_at.not_nil!.to_rfc3339(fraction_digits: 6)
    ).path
    response = ApiClient.new.get("#{path}&locale=en&backdoor_user_id=#{admin.id}")

    response.status_code.should eq(200)
    response.body.should contain("Other comments in this batch (1)")
    response.body.should contain("Restore parents before replies.")
    ApiClient.new.get("#{path}&backdoor_user_id=#{user.id}").status_code.should eq(404)
    ApiClient.new.get("/admin/trash/comments/#{child.id}/batch?deleted_at=invalid&backdoor_user_id=#{admin.id}").status_code.should eq(400)
    ApiClient.new.get("/admin/trash?kind=invalid&backdoor_user_id=#{admin.id}").status_code.should eq(400)
  end
end
