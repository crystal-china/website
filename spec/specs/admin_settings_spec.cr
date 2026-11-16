require "../spec_helper"

describe "Admin site settings" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    previous_smtp_settings = {
      host:     Carbon::SmtpAdapter.settings.host,
      port:     Carbon::SmtpAdapter.settings.port,
      username: Carbon::SmtpAdapter.settings.username,
      password: Carbon::SmtpAdapter.settings.password,
      use_tls:  Carbon::SmtpAdapter.settings.use_tls,
    }

    ENV["ADMIN_EMAILS"] = "settings-admin@example.com"

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  ensure
    if previous_smtp_settings
      Carbon::SmtpAdapter.configure do |settings|
        settings.host = previous_smtp_settings[:host]
        settings.port = previous_smtp_settings[:port]
        settings.username = previous_smtp_settings[:username]
        settings.password = previous_smtp_settings[:password]
        settings.use_tls = previous_smtp_settings[:use_tls]
      end
    end

    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "shows two independent forms with translated tabs and add and remove controls" do
    admin = UserFactory.create &.email("settings-admin@example.com")

    {"zh-CN" => "站点设置", "en" => "Site settings"}.each do |locale, title|
      response = ApiClient.new.get("/admin/settings?backdoor_user_id=#{admin.id}&locale=#{locale}")
      document = XML.parse_html(response.body)
      form = document.xpath_node("//form[@id='site-settings-form']").not_nil!
      mail_form = document.xpath_node("//form[@id='mail-settings-form']").not_nil!
      logo_input = form.xpath_node(".//input[@name='space:logo_url']").not_nil!
      email_input = form.xpath_node(".//input[@name='space:contact_email']").not_nil!
      tls_options = mail_form.xpath_nodes(".//select[@name='space:smtp_tls_mode']/option").to_a

      response.status_code.should eq(200)
      document.xpath_node("//main//aside//a[@href='/admin/settings']").not_nil!.content.should eq(title)
      form["action"].should eq("/admin/settings")
      form["hx-target"].should eq("#site-settings-form")
      mail_form["action"].should eq("/admin/settings/mail")
      mail_form["hx-target"].should eq("#mail-settings-form")
      document.xpath_node("//button[@id='site-settings-tab'][@type='button']").should_not be_nil
      document.xpath_node("//button[@id='mail-settings-tab'][@type='button']").should_not be_nil
      document.xpath_node("//div[@id='mail-settings-panel'][@hidden]").should_not be_nil
      form.xpath_node(".//input[@name='space:smtp_host']").should be_nil
      mail_form.xpath_node(".//input[@name='space:logo_url']").should be_nil
      logo_input["value"].should eq(Space::DEFAULT_LOGO_PATH)
      email_input["value"].should eq(Space::DEFAULT_CONTACT_EMAIL)
      form.xpath_node(".//input[@name='space:source_url']").not_nil!["value"].should eq(Space::DEFAULT_SOURCE_URL)
      form.xpath_node(".//input[@name='space:show_source_link']").should be_nil
      tls_options.size.should eq(1)
      tls_options.first.content.should eq("STARTTLS")
      tls_options.first["value"].should eq("Starttls")
      tls_options.first["selected"]?.should_not be_nil

      {"smtp_host", "smtp_port", "smtp_username", "smtp_password", "email_from"}.each do |field|
        mail_form.xpath_node(".//input[@name='space:#{field}']").not_nil!["value"].should eq("")
      end

      form.xpath_node(".//input[@type='checkbox']").should be_nil
      form.xpath_node(".//fieldset[@id='footer-link-fields'][@disabled]").should be_nil
      form.xpath_node(".//template[@id='footer-link-template']").should_not be_nil
      form.xpath_node(".//div[@id='footer-link-rows']//input[@name='footer_links[0]:title']").should_not be_nil
      form.xpath_node(".//input[@type='hidden'][@name='footer_links']").not_nil!["value"].should eq("")
      form.xpath_nodes(".//div[@class][contains(@class, 'footer-link-row')]").size.should eq(3)

      space = Space::BaseQuery.find(Space::DEFAULT_ID)

      space.logo_url.should be_nil
      space.contact_email.should be_nil
      space.source_url.should be_nil
      space.footer_links.should be_nil
    end
  end

  it "persists the displayed defaults only after the site form is submitted" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {
        logo_url:      Space::DEFAULT_LOGO_PATH,
        contact_email: Space::DEFAULT_CONTACT_EMAIL,
        source_url:    Space::DEFAULT_SOURCE_URL,
      },
      footer_links: Space::DEFAULT_FOOTER_LINKS
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(ApiClient.new.get("/").body)

    response.status_code.should eq(200)
    space.logo_url.should eq(Space::DEFAULT_LOGO_PATH)
    space.contact_email.should eq(Space::DEFAULT_CONTACT_EMAIL)
    space.source_url.should eq(Space::DEFAULT_SOURCE_URL)
    space.footer_links.not_nil!.map(&.icon).should eq(Space::DEFAULT_FOOTER_LINKS.map(&.icon))
    document.xpath_node("//header[@class='site-navbar']/div/a/img").not_nil!["src"].should eq(Lucky::AssetHelpers.asset("svgs/crystal-china.svg"))
    document.xpath_node("//footer//nav/a/img").not_nil!["src"].should eq(Lucky::AssetHelpers.asset("svgs/github-icon.svg"))
  end

  it "preserves blank form parameters before validation rather than converting them to nil" do
    params = Avram::Params.new({"logo_url" => "", "contact_email" => "", "source_url" => ""})
    operation = UpdateSpaceSettings.new(params)

    operation.logo_url.allow_blank?.should be_true
    operation.contact_email.allow_blank?.should be_true
    operation.source_url.allow_blank?.should be_true
    operation.logo_url.value.should eq("")
    operation.contact_email.value.should eq("")
    operation.source_url.value.should eq("")
  end

  it "stores empty strings and an empty link array when the initially unset form is cleared" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {
        logo_url:      "",
        contact_email: "",
        source_url:    "",
      },
      footer_links: [] of Space::FooterLink
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(ApiClient.new.get("/").body)
    form = XML.parse_html(response.body)

    response.status_code.should eq(200)
    space.logo_url.should eq("")
    space.contact_email.should eq("")
    space.source_url.should eq("")
    space.footer_links.not_nil!.should be_empty
    document.xpath_node("//header[@class='site-navbar']/div/a[@href='/']").should be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should be_nil
    document.xpath_node("//footer//address").should be_nil
    document.xpath_nodes("//footer//nav/a").should be_empty

    {"logo_url", "contact_email", "source_url"}.each do |field|
      form.xpath_node("//input[@name='space:#{field}']").not_nil!["value"].should eq("")
    end
  end

  it "saves an empty link array when every existing footer row is removed" do
    admin = UserFactory.create &.email("settings-admin@example.com")

    UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      footer_links: Space::DEFAULT_FOOTER_LINKS
    )

    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {} of String => String,
      footer_links: [] of Space::FooterLink
    )

    response.status_code.should eq(200)
    Space::BaseQuery.find(Space::DEFAULT_ID).footer_links.not_nil!.should be_empty
    XML.parse_html(ApiClient.new.get("/").body).xpath_nodes("//footer//nav/a").should be_empty
  end

  it "keeps explicitly blank inputs blank when another field fails validation" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {
        logo_url:      "",
        contact_email: "",
        source_url:    "",
      },
      footer_links: [{title: "Invalid", url: "javascript:alert(1)", icon: "svgs/github-icon.svg"}]
    )
    document = XML.parse_html(response.body)
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    response.status_code.should eq(200)
    document.xpath_node("//p[contains(@class, 'error')]").should_not be_nil
    document.xpath_nodes("//div[contains(@class, 'footer-link-row')]").size.should eq(1)

    {"logo_url", "contact_email", "source_url"}.each do |field|
      document.xpath_node("//input[@name='space:#{field}']").not_nil!["value"].should eq("")
    end

    space.logo_url.should be_nil
    space.contact_email.should be_nil
    space.source_url.should be_nil
    space.footer_links.should be_nil
  end

  it "groups sparse and interleaved HTML fields by row and supports deleting every row" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    client = ApiClient.new.headers("Content-Type": "application/x-www-form-urlencoded")
    route = Admin::Settings::Update
    body = HTTP::Params.encode({
      "backdoor_user_id"      => admin.id.to_s,
      "space:contact_email"   => "",
      "footer_links"          => "",
      "footer_links[2]:title" => " Code ",
      "footer_links[7]:title" => " Docs ",
      "footer_links[7]:url"   => "https://example.com/docs",
      "footer_links[2]:url"   => "https://example.com/code",
      "footer_links[2]:icon"  => "svgs/github-icon.svg",
      "footer_links[7]:icon"  => "https://example.com/docs.svg",
    })
    response = client.exec_raw(route, body)
    links = Space::BaseQuery.find(Space::DEFAULT_ID).footer_links.not_nil!

    response.status_code.should eq(200)
    links.map(&.title).should eq(["Code", "Docs"])
    links.map(&.url).should eq(["https://example.com/code", "https://example.com/docs"])
    links.map(&.icon).should eq(["svgs/github-icon.svg", "https://example.com/docs.svg"])

    response = client.exec_raw(
      route,
      HTTP::Params.encode({
        "backdoor_user_id"    => admin.id.to_s,
        "space:contact_email" => "",
        "footer_links"        => "",
      })
    )

    response.status_code.should eq(200)
    Space::BaseQuery.find(Space::DEFAULT_ID).footer_links.not_nil!.should be_empty
  end

  it "keeps incomplete rows separate and redisplays their fields without saving any links" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {} of String => String,
      footer_links: [
        {title: "Incomplete", icon: "svgs/github-icon.svg"},
        {title: "Valid", url: "https://example.com", icon: "https://example.com/icon.svg"},
      ]
    )
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.body.should contain("第 1 行")
    document.xpath_node("//input[@name='footer_links[0]:title']").not_nil!["value"].should eq("Incomplete")
    document.xpath_node("//input[@name='footer_links[0]:url']").not_nil!["value"].should eq("")
    document.xpath_node("//input[@name='footer_links[1]:title']").not_nil!["value"].should eq("Valid")
    document.xpath_node("//input[@name='footer_links[1]:url']").not_nil!["value"].should eq("https://example.com")
    Space::BaseQuery.find(Space::DEFAULT_ID).footer_links.should be_nil
  end

  it "saves settings to the default Space and uses them on the next page without restarting" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    client = ApiClient.new
    response = client.put(
      "/admin/settings?backdoor_user_id=#{admin.id}&locale=zh-CN",
      space: {
        logo_url:      "https://example.com/logo.jpg",
        contact_email: "hello@example.com",
        name:          "不得修改名称",
        slug:          "must-not-change",
        topics_count:  999,
      },
      footer_links: [
        {title: "Blog", url: "https://example.com", icon: "https://example.com/icon.png"},
        {title: "", url: "", icon: ""},
      ]
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    document.xpath_node("//form[@id='site-settings-form']").should_not be_nil
    document.xpath_node("//form[@id='mail-settings-form']").should be_nil
    document.xpath_node("//hx-partial[@hx-target='#page-flash']").not_nil!.content.should contain("站点设置已保存")
    space.logo_url.should eq("https://example.com/logo.jpg")
    space.contact_email.should eq("hello@example.com")
    space.footer_links.not_nil!.size.should eq(1)
    space.name.should eq("Crystal 中文社区")
    space.slug.should eq("default")
    space.topics_count.should eq(0)
    Space::BaseQuery.new.select_count.should eq(1)

    document = XML.parse_html(ApiClient.new.get("/").body)

    document.xpath_node("//header[@class='site-navbar']//img").not_nil!["src"].should eq("https://example.com/logo.jpg")
    document.xpath_node("//footer//address/a").not_nil!["href"].should eq("mailto:hello@example.com")
    document.xpath_node("//footer//nav/a").not_nil!["href"].should eq("https://example.com")

    document = XML.parse_html(client.get("/admin/settings?backdoor_user_id=#{admin.id}&locale=zh-CN").body)

    document.xpath_node("//input[@name='space:logo_url']").not_nil!["value"].should eq("https://example.com/logo.jpg")
    document.xpath_node("//input[@name='footer_links[0]:title']").not_nil!["value"].should eq("Blog")
  end

  it "shows or hides the source code link by saving or clearing its URL" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    client = ApiClient.new
    response = client.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {source_url: " https://example.com/source "}
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(client.get("/admin/settings?backdoor_user_id=#{admin.id}").body)

    response.status_code.should eq(200)
    space.source_url.should eq("https://example.com/source")
    space.footer_links.should be_nil
    document.xpath_node("//input[@name='space:source_url']").not_nil!["value"].should eq("https://example.com/source")
    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should_not be_nil

    response = client.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {source_url: ""}
    )

    response.status_code.should eq(200)
    space.reload.source_url.should eq("")

    document = XML.parse_html(client.get("/admin/settings?backdoor_user_id=#{admin.id}").body)

    document.xpath_node("//input[@name='space:source_url']").not_nil!["value"].should eq("")
    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should be_nil
  end

  it "saves SMTP settings without returning the password or accepting encrypted credentials from the browser" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    client = ApiClient.new
    response = client.put(
      "/admin/settings/mail?backdoor_user_id=#{admin.id}&locale=zh-CN",
      space: {
        smtp_host:               "smtp.example.com",
        smtp_port:               587,
        smtp_tls_mode:           "Starttls",
        smtp_username:           "sender@example.com",
        smtp_password:           "secret-smtp-password",
        email_from:              "noreply@example.com",
        encrypted_smtp_password: "must-not-trust-this-value",
      }
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    document.xpath_node("//form[@id='mail-settings-form']").should_not be_nil
    document.xpath_node("//form[@id='site-settings-form']").should be_nil
    document.xpath_node("//hx-partial[@hx-target='#page-flash']").not_nil!.content.should contain("站点设置已保存")
    document.xpath_node("//input[@name='space:smtp_password']").not_nil!["value"].should eq("")
    document.xpath_node("//input[@name='space:clear_smtp_password'][@type='checkbox'][@checked]").should be_nil
    space.smtp_host.should eq("smtp.example.com")
    space.smtp_port.should eq(587)
    space.smtp_tls_mode.should eq(Space::SmtpTlsMode::Starttls)
    space.email_from.should eq("noreply@example.com")
    EncryptedSecret.decrypt(space.encrypted_smtp_password.not_nil!).should eq("secret-smtp-password")
    Carbon::SmtpAdapter.settings.host.should eq("smtp.example.com")
    Carbon::SmtpAdapter.settings.port.should eq(587)
    Carbon::SmtpAdapter.settings.username.should eq("sender@example.com")
    Carbon::SmtpAdapter.settings.password.should eq("secret-smtp-password")
    Carbon::SmtpAdapter.settings.use_tls.should be_true
    BaseEmail.settings.adapter.should be_a(Carbon::DevAdapter)

    response = client.get("/admin/settings?backdoor_user_id=#{admin.id}&locale=zh-CN")
    document = XML.parse_html(response.body)

    response.body.should_not contain("secret-smtp-password")
    response.body.should_not contain(space.encrypted_smtp_password.not_nil!)
    document.xpath_node("//input[@name='space:smtp_password']").not_nil!["value"].should eq("")
    document.xpath_node("//input[@name='space:smtp_host']").not_nil!["value"].should eq("smtp.example.com")
    document.xpath_node("//input[@name='space:smtp_port']").not_nil!["value"].should eq("587")
    document.xpath_node("//main//form/ancestor::section[contains(@class, 'max-w-3xl')]").should_not be_nil
  end

  it "does not let either settings endpoint change fields belonging to the other tab" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    client = ApiClient.new
    space = UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      logo_url: "https://example.com/original.svg",
      footer_links: [
        Space::FooterLink.new(
          title: "Blog",
          url: "https://example.com/blog",
          icon: "https://example.com/blog.svg"
        ),
      ]
    )
    space = UpdateMailSettings.update!(
      space,
      smtp_host: "smtp.example.com",
      smtp_port: 587,
      smtp_username: "sender@example.com",
      smtp_password: "original-password",
      email_from: "sender@example.com"
    )
    response = client.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {
        contact_email: "contact@example.com",
        smtp_host:     "must-not-save.example.com",
        smtp_password: "must-not-save",
        email_from:    "must-not-save@example.com",
      }
    )

    response.status_code.should eq(200)
    space.reload.contact_email.should eq("contact@example.com")
    space.smtp_host.should eq("smtp.example.com")
    space.email_from.should eq("sender@example.com")
    EncryptedSecret.decrypt(space.encrypted_smtp_password.not_nil!).should eq("original-password")

    response = client.put(
      "/admin/settings/mail?backdoor_user_id=#{admin.id}",
      space: {
        smtp_host:     "new-smtp.example.com",
        logo_url:      "https://example.com/must-not-save.svg",
        contact_email: "must-not-save@example.com",
      },
      footer_links: [{title: "must-not-save", url: "https://example.com/must-not-save", icon: "https://example.com/must-not-save.svg"}]
    )

    response.status_code.should eq(200)
    space.reload.smtp_host.should eq("new-smtp.example.com")
    space.logo_url.should eq("https://example.com/original.svg")
    space.contact_email.should eq("contact@example.com")
    space.footer_links.not_nil!.map(&.title).should eq(["Blog"])
  end

  it "rejects unsupported or empty SMTP encryption modes without saving other changes" do
    admin = UserFactory.create &.email("settings-admin@example.com")

    {"SMTPS", "999", ""}.each do |mode|
      response = ApiClient.new.put(
        "/admin/settings/mail?backdoor_user_id=#{admin.id}&locale=zh-CN",
        space: {smtp_tls_mode: mode, smtp_username: "must-not-save@example.com"}
      )
      space = Space::BaseQuery.find(Space::DEFAULT_ID)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//select[@name='space:smtp_tls_mode']/following-sibling::*[contains(@class, 'error')]").should_not be_nil
      space.smtp_tls_mode.should eq(Space::SmtpTlsMode::Starttls)
      space.smtp_username.should be_nil
    end
  end

  it "does not echo a newly entered SMTP password when validation fails" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    previous_smtp_host = Carbon::SmtpAdapter.settings.host
    previous_smtp_port = Carbon::SmtpAdapter.settings.port
    previous_smtp_password = Carbon::SmtpAdapter.settings.password

    response = ApiClient.new.put(
      "/admin/settings/mail?backdoor_user_id=#{admin.id}&locale=zh-CN",
      space: {
        smtp_host:     "smtp.example.com",
        smtp_port:     0,
        smtp_username: "sender@example.com",
        smtp_password: "do-not-echo-this-password",
        email_from:    "noreply@example.com",
      }
    )
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.body.should_not contain("do-not-echo-this-password")
    document.xpath_node("//input[@name='space:smtp_password']").not_nil!["value"].should eq("")
    document.xpath_node("//input[@name='space:smtp_host']").not_nil!["value"].should eq("smtp.example.com")
    document.xpath_node("//form[@id='site-settings-form']").should be_nil
    Space::BaseQuery.find(Space::DEFAULT_ID).encrypted_smtp_password.should be_nil
    Carbon::SmtpAdapter.settings.host.should eq(previous_smtp_host)
    Carbon::SmtpAdapter.settings.port.should eq(previous_smtp_port)
    Carbon::SmtpAdapter.settings.password.should eq(previous_smtp_password)
  end

  it "preserves empty strings from form parameters and hides explicitly cleared settings" do
    admin = UserFactory.create &.email("settings-admin@example.com")

    UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      logo_url: "https://example.com/logo.png",
      contact_email: "hello@example.com"
    )

    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}",
      space: {logo_url: "", contact_email: ""}
    )
    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    document = XML.parse_html(ApiClient.new.get("/admin/settings?backdoor_user_id=#{admin.id}").body)

    response.status_code.should eq(200)
    space.logo_url.should eq("")
    space.contact_email.should eq("")
    document.xpath_node("//input[@name='space:logo_url']").not_nil!["value"].should eq("")
    document.xpath_node("//input[@name='space:contact_email']").not_nil!["value"].should eq("")
  end

  it "keeps invalid input on the form and saves none of the changes" do
    admin = UserFactory.create &.email("settings-admin@example.com")
    response = ApiClient.new.put(
      "/admin/settings?backdoor_user_id=#{admin.id}&locale=zh-CN",
      space: {
        logo_url:      "javascript:alert(1)",
        contact_email: "not-an-email",
        source_url:    "javascript:alert(1)",
      },
      footer_links: [{title: "保留输入", url: "javascript:alert(1)", icon: "https://example.com/icon.svg"}]
    )
    document = XML.parse_html(response.body)
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    response.status_code.should eq(200)
    response.headers["HX-Push-Url"].should eq("false")
    document.xpath_node("//form[@id='mail-settings-form']").should be_nil
    document.xpath_node("//input[@name='space:logo_url']").not_nil!["value"].should eq("javascript:alert(1)")
    document.xpath_node("//input[@name='space:source_url']").not_nil!["value"].should eq("javascript:alert(1)")
    document.xpath_node("//input[@name='footer_links[0]:title']").not_nil!["value"].should eq("保留输入")
    response.body.should contain("第 1 行")
    space.logo_url.should be_nil
    space.contact_email.should be_nil
    space.source_url.should be_nil
    space.footer_links.should be_nil
  end

  it "rejects non-administrators on both the form and save endpoint" do
    user = UserFactory.create
    client = ApiClient.new

    client.get("/admin/settings?backdoor_user_id=#{user.id}").status_code.should eq(404)
    client.put("/admin/settings?backdoor_user_id=#{user.id}", space: {contact_email: "hacked@example.com"}).status_code.should eq(404)
    client.put("/admin/settings/mail?backdoor_user_id=#{user.id}", space: {smtp_host: "hacked.example.com"}).status_code.should eq(404)
    Space::BaseQuery.find(Space::DEFAULT_ID).contact_email.should be_nil
    Space::BaseQuery.find(Space::DEFAULT_ID).smtp_host.should be_nil
  end
end
