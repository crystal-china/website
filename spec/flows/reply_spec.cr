require "../spec_helper"

describe "Create reply to doc and reply to reply", tags: "flow" do
  it "works" do
    flow = AuthenticationFlow.new("test@example.com")
    flow.sign_up "password"
    flow.should_be_signed_in
    flow.open_doc
    flow.create_two_reply_to_doc
    flow.delete_first_reply
    flow.edit_reply
    flow.should have_element(css_selector: "article#doc_reply-2", text: "hello world!")
    flow.create_reply_to_reply
    flow.should have_element(css_selector: "article#doc_reply-3", text: "reply to reply test")
  end
end
