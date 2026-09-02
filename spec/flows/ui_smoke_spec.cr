require "../spec_helper"

pending "Critical browser flows", tags: "headless_chrome" do
  it "signs in and signs out" do
    user = UserFactory.create
    flow = BaseFlow.new

    flow.visit SignIns::New
    flow.fill_form SignInUser,
      email: user.email,
      password: "password"
    flow.click "@sign-in-button"
    sleep 0.8.seconds

    flow.should have_current_path("/")
    flow.should have_element("@sign-out-button")

    flow.click "@sign-out-button"
    sleep 0.8.seconds

    flow.should have_current_path("/sign_in")
    flow.should have_element("@sign-in-button")
  end

  it "opens the documentation search dialog" do
    flow = BaseFlow.new
    flow.visit "/docs/index"

    flow.js_bool("return document.getElementById('doc_search_dialog').open;").should be_false
    flow.dom_click("[flow-id='doc_index']")
    flow.js_bool("return document.getElementById('doc_search_dialog').open;").should be_true
  end

  it "previews and creates a top-level reply" do
    user = UserFactory.create
    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    flow.el("textarea#tab_text_area").fill("hello **world**")
    flow.dom_click("[flow-id='tab-preview_reply']")
    flow.should have_element("div.markdown-preview", text: "hello world")

    flow.dom_click("[flow-id='tab-do_reply']")
    flow.should have_element("article", text: "hello world")
    flow.el("div.panel1").displayed?.should be_true
    flow.el("div.panel2").displayed?.should be_false
    flow.el("textarea#tab_text_area").text.should eq ""
  end

  it "loads and collapses a reply thread" do
    user = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/index")
    root_reply = SaveReply.create!(user_id: user.id, doc_id: doc.id, content: "root reply")
    SaveReply.create!(user_id: user.id, reply_id: root_reply.id, content: "child reply")

    flow = BaseFlow.new
    flow.visit "/docs/index?backdoor_user_id=#{user.id}"

    flow.should have_element("button", text: "加载子评论，共 1 条")
    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-load_thread']")
    flow.should have_element("article", text: "child reply")

    flow.dom_click("[flow-id='doc_reply-#{root_reply.id}-collapse_thread']")
    flow.js_bool(<<-JS).should be_true
      const replies = document.getElementById('doc_reply-#{root_reply.id}-replies');
      return replies !== null && replies.innerHTML.trim() === '';
    JS
  end
end
