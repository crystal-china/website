require "../spec_helper"

describe "Create reply to doc and reply to reply", tags: "flow" do
  it "works" do
    flow = AuthenticationFlow.new("test@example.com")
    flow.sign_up "password"
    flow.should_be_signed_in

    flow.sign_out
    flow.sign_in "wrong-password"
    flow.should_have_password_error

    flow.sign_in "password"
    flow.should_be_signed_in

    flow.open_doc
    flow.create_two_reply_to_doc
    flow.delete_first_reply
    flow.edit_reply
    flow.should have_element(css_selector: "article#doc_reply-2", text: "hello world!")
    flow.create_reply_to_reply
    flow.should have_element(css_selector: "article#doc_reply-3", text: "reply to reply test")
  end

  # This is to show you how to sign in as a user during tests.
  # Use the `visit` method's `as` option in your tests to sign in as that user.
  #
  # Feel free to delete this once you have other tests using the 'as' option.
  # it "allows sign in through backdoor when testing" do
  #   user = UserFactory.create
  #   flow = BaseFlow.new

  #   flow.visit Me::Show, as: user
  #   should_be_signed_in(flow)
  # end
end
