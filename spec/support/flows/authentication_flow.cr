class AuthenticationFlow < BaseFlow
  private getter email

  def initialize(@email : String)
  end

  def sign_up(password)
    visit SignUps::New
    fill_form SignUpUser,
      email: email,
      password: password,
      password_confirmation: password
    el("span#signup_captcha").click
    # CAPTCHA_CACHE.keys.size.should eq 1
    # signup_captcha_id = CAPTCHA_CACHE.keys.first
    CAPTCHA_LOCK.synchronize do
      CAPTCHA_CACHE.keys.each do |e|
        CAPTCHA_CACHE.write(e, "foo", expires_in: 10.minutes)
      end
    end
    fill "captcha", with: "foo"
    click "@sign-up-button"
  end

  def sign_out
    visit Me::Show
    sign_out_button.click
  end

  def sign_in(password)
    visit SignIns::New
    fill_form SignInUser,
      email: email,
      password: password
    click "@sign-in-button"
  end

  def open_doc
    # el("header nav ul > li:first-child > a").click
    click "@doc_index"
  end

  def create_two_reply_to_doc
    textarea = el("textarea#tab_text_area")
    textarea.click
    textarea.fill("hello!")
    click "@tab-preview_reply"
    click "@tab-do_reply"
    click "@tab-input_reply"
    textarea.fill("crystal china!")
    click "@tab-do_reply"
    sleep 0.5.seconds
  end

  def delete_first_reply
    delete_link = driver.find_xpath("//article[@id='doc_reply-1']//a[text()='删除']").first
    sleep 0.5.seconds
    delete_link.click
    sleep 0.5.seconds
    accept_alert
    sleep 0.5.seconds
  end

  def edit_reply
    edit_link = driver.find_xpath("//article[@id='doc_reply-2']//a[text()='编辑']").first
    edit_link.click
    sleep 0.5.seconds
    text_area = el("textarea#reply_to_reply_text_area")
    text_area.click
    text_area.fill("hello world!")
    sleep 0.5.seconds
    click "@reply_to_reply-preview_reply"
    sleep 0.5.seconds
    click "@reply_to_reply-do_reply"
  end

  def create_reply_to_reply
    reply = driver.find_xpath("//article[@id='doc_reply-1']//a[text()='删除']").first
  end

  def should_be_signed_in
    current_page.should have_element("@sign-out-button")
  end

  def should_have_password_error
    current_page.should have_element("div.error", text: "Password is wrong")
  end

  private def sign_out_button
    el("@sign-out-button")
  end

  # NOTE: this is a shim for readability
  private def current_page
    self
  end
end
