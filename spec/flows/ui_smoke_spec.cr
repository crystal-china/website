require "../spec_helper"

describe "UI smoke tests", tags: "headless_chrome" do
  it "renders the home page skeleton" do
    flow = BaseFlow.new

    flow.visit Home::Index
    sleep 0.8.seconds

    flow.should have_current_path(Home::Index)
    flow.should have_element("canvas#logo-canvas")
    flow.should have_element("h1", text: "The Crystal programming language 中文站")
    flow.should have_element("h2", text: "Official")
    flow.should have_element("h2", text: "Docs")
    flow.should have_element("h2", text: "Packages")
    flow.should have_element("h2", text: "Organizations")
    flow.should have_element("a", text: "Crystal website")
    flow.should have_element("@doc_index")
  end

  it "renders the sign in form and oauth panel" do
    flow = BaseFlow.new

    flow.visit SignIns::New

    flow.should have_current_path(SignIns::New)
    flow.should have_element("form")
    flow.should have_element("input[type='email']")
    flow.should have_element("input[type='password']")
    flow.should have_element("aside", text: "快捷登录")
    flow.should have_element("@sign-in-button")
  end

  it "highlights the current nav item on the sign in page" do
    flow = BaseFlow.new

    flow.visit SignIns::New

    flow.js_bool(
      <<-JS
        const signInLink = [...document.querySelectorAll("a")].find((el) => el.textContent.trim() === "登录");
        return signInLink && signInLink.className.includes("bg-gray-200");
      JS
    ).should be_true

    flow.js_bool(
      <<-JS
        const signUpLink = [...document.querySelectorAll("a")].find((el) => el.textContent.trim() === "注册");
        return signUpLink && signUpLink.className.includes("bg-gray-200");
      JS
    ).should be_false
  end

  it "renders the sign up form with captcha trigger" do
    flow = BaseFlow.new

    flow.visit SignUps::New

    flow.should have_current_path(SignUps::New)
    flow.should have_element("input[type='email']")
    flow.should have_element("input[type='password']")
    flow.should have_element("#captcha")
    flow.should have_element("#signup_captcha", text: "点击获取人机验证码")
    flow.should have_element("@sign-up-button")
  end

  it "signs in successfully and redirects with a flash message" do
    user = UserFactory.create
    flow = AuthenticationFlow.new(user.email)

    flow.sign_in("password")
    sleep 0.8.seconds

    flow.should have_current_path(Home::Index)
    flow.should have_element("@flash", text: "登录成功")
    flow.should have_element("@sign-out-button")
  end

  it "stays on the sign in page and shows an error when the password is wrong" do
    user = UserFactory.create
    flow = AuthenticationFlow.new(user.email)

    flow.sign_in("wrong-password")
    sleep 1.2.seconds

    flow.should have_current_path(SignIns::New)
    flow.should have_element("div.error", text: "is wrong")
  end

  it "redirects signed-in users away from the sign in page" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit SignIns::New, as: user
    sleep 0.8.seconds

    flow.should have_current_path(Home::Index)
    flow.should have_element("@flash", text: "您已经登录")
  end

  it "signs out successfully and redirects with a flash message" do
    user = UserFactory.create
    flow = AuthenticationFlow.new(user.email)

    flow.sign_in("password")
    sleep 0.8.seconds
    flow.sign_out
    sleep 0.8.seconds

    flow.should have_current_path(SignIns::New)
    flow.should have_element("@flash", text: "取消登录成功")
    flow.should have_element("@sign-in-button")
  end

  it "renders the password reset request form" do
    flow = BaseFlow.new

    flow.visit PasswordResetRequests::New

    flow.should have_current_path(PasswordResetRequests::New)
    flow.should have_element("form")
    flow.should have_element("input[type='email']")
    flow.should have_element("@request-password-reset-button")
    flow.should have_element("a", text: "返回登录")
  end

  it "renders the profile edit form and avatar preview" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit Me::Edit, as: user

    flow.should have_current_path(Me::Edit)
    flow.should have_element("h1", text: "编辑我的信息")
    flow.should have_element("label", text: "昵称")
    flow.should have_element("label", text: "头像链接")
    flow.should have_element("label", text: "密码")
    flow.should have_element("label", text: "确认密码")
    flow.should have_element("figure", text: "头像预览")
    flow.should have_element("a", text: "返回")
    flow.should have_element("input[type='submit'][value='保存修改']")
  end

  it "updates the profile and redirects with a flash message" do
    user = UserFactory.create
    flow = BaseFlow.new
    new_name = "updated-#{Random.rand(1_000_000)}"
    new_avatar = "https://example.com/avatar.png"

    flow.visit Me::Edit, as: user
    flow.fill_form UpdateUser,
      name: new_name,
      avatar: new_avatar,
      password: "",
      password_confirmation: ""
    flow.click("input[type='submit'][value='保存修改']")
    sleep 0.8.seconds

    flow.should have_current_path(Home::Index)
    flow.should have_element("@flash", text: "更新成功！")

    updated_user = UserQuery.find(user.id)
    updated_user.name.should eq new_name
    updated_user.avatar.should eq new_avatar
  end

  it "stays on edit page and shows an error when profile update fails" do
    user = UserFactory.create
    flow = BaseFlow.new
    new_name = "invalid-avatar-#{Random.rand(1_000_000)}"

    flow.visit Me::Edit, as: user
    flow.fill_form UpdateUser,
      name: new_name,
      avatar: "not-a-url",
      password: "",
      password_confirmation: ""
    flow.click("input[type='submit'][value='保存修改']")
    sleep 0.8.seconds

    flow.should have_current_path(Me::Edit)
    flow.should have_element("h1", text: "编辑我的信息")
    flow.should have_element("div", text: "http/https")
  end

  it "keeps the docs search dialog hidden until opened" do
    flow = BaseFlow.new

    flow.visit "/docs/index"

    flow.js_bool(
      "return document.getElementById('doc_search_dialog').open;"
    ).should be_false

    flow.click("@doc_index")
    sleep 0.3.seconds

    flow.js_bool(
      "return document.getElementById('doc_search_dialog').open;"
    ).should be_true
    flow.should have_element("#search-input")
  end

  it "closes and reopens the docs search dialog" do
    flow = BaseFlow.new

    flow.visit "/docs/index"
    flow.click("@doc_index")
    sleep 0.3.seconds

    flow.js_bool(
      "return document.getElementById('doc_search_dialog').open;"
    ).should be_true

    flow.js_eval("document.getElementById('doc_search_dialog').close()")
    sleep 0.2.seconds

    flow.js_bool(
      "return document.getElementById('doc_search_dialog').open;"
    ).should be_false

    flow.click("@doc_index")
    sleep 0.3.seconds

    flow.js_bool(
      "return document.getElementById('doc_search_dialog').open;"
    ).should be_true
  end

  it "renders the docs pager with current and neighboring pages" do
    flow = BaseFlow.new

    flow.visit "/docs/index"
    sleep 0.5.seconds

    flow.should have_element("nav[aria-label='文档分页']")
    flow.should have_element("strong", text: "前言")
    flow.should have_element("strong", text: "没有上一页了")
    flow.should have_element("a", text: "简介")
  end

  it "redirects guests to sign in with a flash message" do
    flow = BaseFlow.new

    flow.visit Me::Edit
    sleep 0.5.seconds

    flow.should have_current_path(SignIns::New)
    flow.should have_element("@flash", text: "请首先登录")
  end

  it "shows a disabled reply form for guests" do
    flow = BaseFlow.new

    flow.visit "/docs/index"
    sleep 0.8.seconds

    flow.should have_element("output", text: "登录后添加评论")
    flow.el("textarea#tab_text_area").attribute("disabled").should_not be_nil
  end

  it "shows the reply input panel by default" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    flow.el("div.panel1").displayed?.should be_true
    flow.el("div.panel2").displayed?.should be_false
  end

  it "allows switching to preview even when content is empty" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.dom_click("[flow-id='tab-preview_reply']")
    sleep 0.5.seconds

    flow.el("div.panel1").displayed?.should be_false
    flow.el("div.panel2").displayed?.should be_true
  end

  it "switches the reply form between input and preview" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    textarea = flow.el("textarea#tab_text_area")
    textarea.attribute("disabled").should be_nil
    textarea.click
    textarea.fill("hello **world**")
    flow.el("body").send_keys([:page_down])
    sleep 0.3.seconds

    flow.dom_click("[flow-id='tab-preview_reply']")
    sleep 0.5.seconds

    flow.el("div.panel1").displayed?.should be_false
    flow.el("div.panel2").displayed?.should be_true
    flow.should have_element("div.markdown-preview", text: "hello world")

    flow.dom_click("[flow-id='tab-input_reply']")
    sleep 0.3.seconds

    flow.el("div.panel1").displayed?.should be_true
    flow.el("div.panel2").displayed?.should be_false
  end

  it "creates a reply on the docs page" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    textarea = flow.el("textarea#tab_text_area")
    textarea.attribute("disabled").should be_nil
    textarea.click
    textarea.fill("smoke reply")
    flow.click("@tab-do_reply")
    sleep 0.8.seconds

    flow.should have_element("article", text: "smoke reply")
  end

  it "creates a reply from preview and resets the root form" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    textarea = flow.el("textarea#tab_text_area")
    textarea.click
    textarea.fill("preview submit reply")
    flow.dom_click("[flow-id='tab-preview_reply']")
    sleep 0.5.seconds

    flow.el("div.panel2").displayed?.should be_true
    flow.dom_click("[flow-id='tab-do_reply']")
    sleep 0.8.seconds

    flow.should have_element("article", text: "preview submit reply")
    flow.el("div.panel1").displayed?.should be_true
    flow.el("div.panel2").displayed?.should be_false
    flow.el("textarea#tab_text_area").text.should eq ""
  end

  it "sorts root replies between newest and oldest" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "older root reply")
    SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "newer root reply")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.should have_element("span", text: "共 2 条回复")
    first_root_reply_text(flow).should contain("newer root reply")

    flow.driver.find_xpath("//div[@id='replies']//a[text()='最早']").first.click
    sleep 0.8.seconds

    first_root_reply_text(flow).should contain("older root reply")

    flow.driver.find_xpath("//div[@id='replies']//a[text()='最新']").first.click
    sleep 0.8.seconds

    first_root_reply_text(flow).should contain("newer root reply")
  end

  it "keeps root reply order_by after submitting a new reply" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "older root reply")
    SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "newer root reply")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//div[@id='replies']//a[text()='最早']").first.click
    sleep 0.8.seconds

    first_root_reply_text(flow).should contain("older root reply")
    flow.el("textarea#tab_text_area").fill("reply submitted after asc sort")
    flow.dom_click("[flow-id='tab-do_reply']")
    sleep 0.8.seconds

    flow.should have_element("article", text: "reply submitted after asc sort")
    first_root_reply_text(flow).should contain("older root reply")
  end

  it "opens the reply dialog for an existing reply" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "reply dialog root")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='回复']").first.click
    sleep 0.8.seconds

    flow.js_bool(
      "return document.getElementById('edit_dialog').open;"
    ).should be_true
    flow.should have_element("textarea#reply_to_reply_text_area")
    flow.should have_element("button", text: "取消")
    flow.should have_element("button", text: "回复")
  end

  it "closes the reply dialog when cancel is clicked" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "cancel dialog root")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='回复']").first.click
    sleep 0.8.seconds

    flow.js_bool(
      "return document.getElementById('edit_dialog').open;"
    ).should be_true

    flow.driver.find_xpath("//dialog[@id='edit_dialog']//button[text()='取消']").first.click
    sleep 0.3.seconds

    flow.js_bool(
      "return document.getElementById('edit_dialog').open;"
    ).should be_false
  end

  it "opens the edit dialog with the existing reply content" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "editable root reply")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='编辑']").first.click
    sleep 0.8.seconds

    flow.js_bool(
      "return document.getElementById('edit_dialog').open;"
    ).should be_true
    flow.el("textarea#reply_to_reply_text_area").attribute("value").should be_nil
    flow.el("textarea#reply_to_reply_text_area").text.should eq "editable root reply"
    flow.should have_element("button", text: "取消")
    flow.should have_element("button", text: "修改")
  end

  it "updates a root reply from the edit dialog" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "reply before edit")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='编辑']").first.click
    sleep 0.8.seconds

    textarea = flow.el("textarea#reply_to_reply_text_area")
    textarea.clear
    textarea.fill("reply after edit")
    flow.dom_click("[flow-id='reply_to_reply-do_reply']")
    sleep 1.0.seconds

    flow.should have_element("article#doc_reply-#{root_reply.id}", text: "reply after edit")
    flow.should have_element("article#doc_reply-#{root_reply.id}", text: "更新成功")
  end

  it "deletes a root reply from the docs page" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "reply to delete")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='删除']").first.click
    sleep 0.3.seconds
    flow.accept_alert
    sleep 1.2.seconds

    flow.js_bool(
      "return document.getElementById('doc_reply-#{root_reply.id}') !== null;"
    ).should be_false
  end

  it "creates a child reply from the reply dialog" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "thread root reply")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='回复']").first.click
    sleep 0.8.seconds

    textarea = flow.el("textarea#reply_to_reply_text_area")
    textarea.click
    textarea.fill("child reply from dialog")
    flow.dom_click("[flow-id='reply_to_reply-do_reply']")
    sleep 1.0.seconds

    ReplyQuery.find(root_reply.id).root_replies_count.should eq 1
    flow.should have_element("article", text: "child reply from dialog")
  end

  it "creates multiple child replies for the same root reply" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "thread root reply twice")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='回复']").first.click
    sleep 0.8.seconds

    textarea = flow.el("textarea#reply_to_reply_text_area")
    textarea.click
    textarea.fill("first child reply")
    flow.dom_click("[flow-id='reply_to_reply-do_reply']")
    sleep 1.0.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{root_reply.id}']//a[text()='回复']").first.click
    sleep 0.8.seconds

    textarea = flow.el("textarea#reply_to_reply_text_area")
    textarea.clear
    textarea.fill("second child reply")
    flow.dom_click("[flow-id='reply_to_reply-do_reply']")
    sleep 1.0.seconds

    ReplyQuery.find(root_reply.id).root_replies_count.should eq 2
    flow.should have_element("article", text: "first child reply")
    flow.should have_element("article", text: "second child reply")
  end

  it "updates a child reply from the edit dialog" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "root for child edit")
    insert_child_reply_for_test(user: user, root_reply: root_reply, content: "child before edit")
    AppDatabase.exec "UPDATE replies SET root_replies_count = 1 WHERE id = $1", root_reply.id

    child_reply = ReplyQuery.new.reply_id(root_reply.id).first
    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-load_thread']")
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{child_reply.id}']//a[text()='编辑']").first.click
    sleep 0.8.seconds

    textarea = flow.el("textarea#reply_to_reply_text_area")
    textarea.clear
    textarea.fill("child after edit")
    flow.dom_click("[flow-id='reply_to_reply-do_reply']")
    sleep 1.0.seconds

    flow.should have_element("article#doc_reply-#{child_reply.id}", text: "child after edit")
  end

  it "deletes a child reply from the expanded thread" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "root for child delete")
    insert_child_reply_for_test(user: user, root_reply: root_reply, content: "child to delete")
    AppDatabase.exec "UPDATE replies SET root_replies_count = 1 WHERE id = $1", root_reply.id

    child_reply = ReplyQuery.new.reply_id(root_reply.id).first
    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"
    sleep 0.8.seconds

    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-load_thread']")
    sleep 0.8.seconds

    flow.driver.find_xpath("//article[@id='doc_reply-#{child_reply.id}']//a[text()='删除']").first.click
    sleep 0.3.seconds
    flow.accept_alert
    sleep 1.2.seconds

    flow.js_bool(
      "return document.getElementById('doc_reply-#{child_reply.id}') !== null;"
    ).should be_false
  end

  it "loads and collapses child replies for a root reply" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "root smoke reply")
    insert_child_reply_for_test(user: user, root_reply: root_reply, content: "child smoke reply")
    AppDatabase.exec "UPDATE replies SET root_replies_count = 1 WHERE id = $1", root_reply.id

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    flow.should have_element("article", text: "root smoke reply")
    flow.should have_element("a", text: "加载子评论，共 1 条")

    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-load_thread']")
    sleep 0.8.seconds

    flow.should have_element("article", text: "child smoke reply")
    flow.should have_element("a", text: "折叠子评论")

    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-collapse_thread']")
    sleep 0.3.seconds

    flow.js_bool(
      <<-JS,
        const replies = document.getElementById('doc_reply-#{root_reply.id}-replies');
        return replies !== null && replies.innerHTML.trim() === "";
      JS
    ).should be_true
    flow.js_bool(
      <<-JS,
        const link = document.querySelector("[flow-id='doc_reply-#{root_reply.id}-load_thread']");
        return link && !link.hidden;
      JS
    ).should be_true
  end
end

private def first_root_reply_text(flow : BaseFlow) : String
  flow.driver.find_xpath("//div[@id='replies']//article[1]").first.text
end

private def insert_child_reply_for_test(*, user : User, root_reply : Reply, content : String)
  now = Time.utc
  preferences = {
    path_for_doc: nil,
  }.to_json
  votes = {
    "👍"  => 0,
    "👎"  => 0,
    "😄"  => 0,
    "❤️" => 0,
    "🎉"  => 0,
    "😕"  => 0,
    "👀️" => 0,
  }.to_json

  AppDatabase.exec <<-SQL, root_reply.id, root_reply.id, user.id, content, user.name, preferences, votes, now, now
    INSERT INTO replies (
      reply_id,
      root_reply_id,
      user_id,
      content,
      user_name,
      preferences,
      votes,
      created_at,
      updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
  SQL
end
