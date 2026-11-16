require "../spec_helper"

private def configured_mail_space : Space
  UpdateMailSettings.update!(
    Space::BaseQuery.find(Space::DEFAULT_ID),
    smtp_host: "smtp.example.com",
    smtp_port: 587,
    smtp_username: "sender@example.com",
    smtp_password: "smtp-app-password",
    email_from: "noreply@example.com"
  )
end

describe "Site mail settings" do
  it "defaults to STARTTLS without default SMTP credentials or sender address" do
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    space.smtp_host.should be_nil
    space.smtp_port.should be_nil
    space.smtp_tls_mode.should eq(Space::SmtpTlsMode::Starttls)
    space.smtp_username.should be_nil
    space.encrypted_smtp_password.should be_nil
    space.email_from.should be_nil

    expect_raises(BaseEmail::NotConfigured) do
      PasswordResetRequestEmail.new(UserFactory.create).from
    end
  end

  it "encrypts the SMTP password and keeps it when the password input is empty" do
    space = configured_mail_space
    encrypted_password = space.reload.encrypted_smtp_password.not_nil!

    encrypted_password.should_not eq("smtp-app-password")
    EncryptedSecret.decrypt(encrypted_password).should eq("smtp-app-password")

    space = UpdateSpaceSettings.update!(space, contact_email: "contact@example.com")
    space = UpdateMailSettings.update!(space, smtp_password: "")

    space.encrypted_smtp_password.should eq(encrypted_password)
    space.email_from.should eq("noreply@example.com")
    space.contact_email.should eq("contact@example.com")

    space = UpdateMailSettings.update!(space, smtp_password: "replacement-password")

    EncryptedSecret.decrypt(space.encrypted_smtp_password.not_nil!).should eq("replacement-password")

    space = UpdateMailSettings.update!(space, smtp_username: "", clear_smtp_password: true)

    space.smtp_username.should be_nil
    space.encrypted_smtp_password.should be_nil
    Carbon::SmtpAdapter.temp_config(
      host: "localhost",
      port: 25,
      username: nil,
      password: nil,
      use_tls: true
    ) do
      BaseEmail.configure_smtp(space)

      Carbon::SmtpAdapter.settings.username.should be_nil
      Carbon::SmtpAdapter.settings.password.should be_nil
    end
  end

  it "configures the original SMTP adapter and reloads settings only when requested" do
    space = configured_mail_space
    user = UserFactory.create

    Carbon::SmtpAdapter.temp_config(
      host: "localhost",
      port: 25,
      username: nil,
      password: nil,
      use_tls: true
    ) do
      BaseEmail.configure_smtp(space)

      Carbon::SmtpAdapter.settings.host.should eq("smtp.example.com")
      Carbon::SmtpAdapter.settings.port.should eq(587)
      Carbon::SmtpAdapter.settings.username.should eq("sender@example.com")
      Carbon::SmtpAdapter.settings.password.should eq("smtp-app-password")
      Carbon::SmtpAdapter.settings.use_tls.should be_true
      PasswordResetRequestEmail.new(user).from.address.should eq("noreply@example.com")

      space = UpdateMailSettings.update!(
        space,
        smtp_host: "other-smtp.example.com",
        smtp_port: 2525,
        email_from: "new-sender@example.com"
      )

      Carbon::SmtpAdapter.settings.host.should eq("smtp.example.com")
      Carbon::SmtpAdapter.settings.port.should eq(587)
      PasswordResetRequestEmail.new(user).from.address.should eq("new-sender@example.com")

      BaseEmail.configure_smtp(space)

      Carbon::SmtpAdapter.settings.host.should eq("other-smtp.example.com")
      Carbon::SmtpAdapter.settings.port.should eq(2525)
      Carbon::SmtpAdapter.settings.password.should eq("smtp-app-password")
    end
  end

  it "rejects incomplete mail settings without saving other changes" do
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    UpdateMailSettings.update(
      space,
      smtp_host: "smtp.example.com",
      smtp_username: "sender@example.com",
      smtp_password: "must-not-save"
    ) do |operation, _|
      operation.saved?.should be_false
      operation.smtp_port.errors.should_not be_empty
      operation.email_from.errors.should_not be_empty
    end

    space.reload.smtp_host.should be_nil
    space.smtp_username.should be_nil
    space.encrypted_smtp_password.should be_nil
  end

  it "validates the SMTP port, sender, and authentication pair" do
    space = configured_mail_space

    UpdateMailSettings.update(space, smtp_port: 65536, email_from: "invalid") do |operation, _|
      operation.saved?.should be_false
      operation.smtp_port.errors.should_not be_empty
      operation.email_from.errors.should_not be_empty
    end

    UpdateMailSettings.update(space, clear_smtp_password: true) do |operation, _|
      operation.saved?.should be_false
      operation.smtp_password.errors.should_not be_empty
    end

    space.reload.smtp_port.should eq(587)
    space.email_from.should eq("noreply@example.com")
    EncryptedSecret.decrypt(space.encrypted_smtp_password.not_nil!).should eq("smtp-app-password")
  end

  it "disables sending when the basic mail settings are cleared" do
    space = UpdateMailSettings.update!(
      configured_mail_space,
      smtp_host: "",
      smtp_port: nil,
      email_from: ""
    )

    space.smtp_host.should be_nil
    space.smtp_port.should be_nil
    space.email_from.should be_nil

    expect_raises(BaseEmail::NotConfigured) do
      PasswordResetRequestEmail.new(UserFactory.create).from
    end
  end

  it "shows a normal failure when production email delivery is not configured" do
    user = UserFactory.create

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      BaseEmail.temp_config(adapter: Carbon::SmtpAdapter.new) do
        response = ApiClient.new.post(
          "/password_reset_requests?locale=zh-CN",
          request_password_reset: {email: user.email}
        )

        response.status_code.should eq(200)
        response.headers["HX-Push-Url"].should eq("false")
        response.body.should contain("邮件服务尚未配置")
        XML.parse_html(response.body).xpath_node("//form[@action='/password_reset_requests']").should_not be_nil
        Carbon::DevAdapter.delivered_emails.should be_empty
      end
    end
  end
end
