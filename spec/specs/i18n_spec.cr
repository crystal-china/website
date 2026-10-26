require "../spec_helper"

private class TranslationValidationProbe < Avram::Operation
  attribute position : Float64
  attribute url : String

  def run : Nil
    validate_numeric position, at_least: 1.5, no_more_than: 2.5
    validate_url_format url
  end
end

describe "Internationalization" do
  it "rejects missing keys, interpolation arguments and locale catalogs at compile time" do
    {
      "missing_key"           => "Missing translation for \"missing.translation.for_compile_test\"",
      "missing_interpolation" => "total",
      "missing_locale"        => "zh-CN",
      "missing_field"         => "Missing translation for \"fields.missing_field_for_compile_test\"",
    }.each do |fixture, expected|
      output = IO::Memory.new
      status = Process.run("crystal", ["build", "--no-codegen", "--no-color", "spec/fixtures/i18n/#{fixture}.cr"], output: output, error: output)

      status.success?.should be_false
      output.to_s.should contain(expected)
    end
  end

  it "uses one label catalog for static fields and Avram's dynamic field names" do
    {"zh-CN" => "密码", "en" => "Password"}.each do |locale, label|
      Rosetta.with_locale(locale) do
        Rosetta.find("fields.password").t.should eq(label)
        ValidationErrors.field_name(:password).should eq(label)
        ValidationErrors.format(:password, Avram.settings.i18n_backend.get(:validate_required)).should eq(
          Rosetta.find("avram.error").t(field: label, message: Rosetta.find("avram.validate_required").t)
        )
      end
    end
  end

  it "covers every standard Avram validation, including URLs and decimal limits" do
    keys = %i[
      validate_acceptance_of validate_at_most_one_filled validate_confirmation_of
      validate_exact_size_of validate_exactly_one_filled validate_format_of
      validate_inclusion_of validate_max_size_of validate_min_size_of
      validate_numeric_max validate_numeric_min validate_numeric_nil
      validate_required validate_uniqueness_of validate_url_format
    ]

    Rosetta.available_locales.each do |locale|
      Rosetta.with_locale(locale) do
        keys.each { |key| Avram.settings.i18n_backend.get(key).should_not be_empty }
        operation = TranslationValidationProbe.new(position: 1.25, url: "http://example.com")
        operation.run

        operation.position.errors.should eq([Rosetta.find("avram.validate_numeric_min").t(size: "1.5")])
        operation.url.errors.should eq([Rosetta.find("avram.validate_url_format").t(scheme: "https")])
      end
    end
  end

  it "localizes upstream type-casting errors when they are created" do
    Rosetta.available_locales.each do |locale|
      Rosetta.with_locale(locale) do
        operation = SaveNode.new(Avram::Params.new({"position" => "not-a-number"}))

        operation.position.errors.should eq([Rosetta.find("avram.validate_format_of").t])
        attribute = Avram::Attribute(String).new(:name, nil, "node")
        attribute.add_error
        attribute.errors.should eq([Rosetta.find("avram.validate_format_of").t])
      end
    end
  end

  it "renders English pages and remembers the locale for later requests" do
    client = ApiClient.new
    response = client.get("/sign_up?locale=en")
    document = XML.parse_html(response.body)
    headers = HTTP::Headers.new
    HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

    response.status_code.should eq(200)
    document.xpath_node("//html").not_nil!["lang"].should eq("en")
    document.xpath_node("//main//h1").not_nil!.content.should eq("Sign up")
    document.xpath_node("//label[@for='user_email']").not_nil!.content.should eq("Email")
    messages = JSON.parse(document.xpath_node("//script[@id='i18n-messages']").not_nil!.content)
    messages["forbidden"].as_s.should eq("You do not have permission to perform this action.")
    messages["file_too_large"].as_s.should contain("%{size}")

    client.headers(Cookie: headers["Cookie"])
    response = client.get("/sign_in")
    XML.parse_html(response.body).xpath_node("//html").not_nil!["lang"].should eq("en")

    response = client.get("/sign_in?locale=zh-CN")
    document = XML.parse_html(response.body)
    document.xpath_node("//html").not_nil!["lang"].should eq("zh-CN")
    document.xpath_node("//main//h1").not_nil!.content.should eq("登录")
  end

  it "rejects unsupported request locales without passing them to Rosetta" do
    ApiClient.new.get("/sign_in?locale=invalid").status_code.should eq(400)
    ApiClient.new.get("/sign_in").status_code.should eq(200)
  end

  it "localizes the home heading and both initial and loaded release labels" do
    environment = ENV["LUCKY_ENV"]
    ENV["LUCKY_ENV"] = "development"

    {
      "zh-CN" => {"Crystal 编程语言中文站", "最新版本："},
      "en"    => {"The Crystal programming language - Chinese community", "Latest release:"},
    }.each do |locale, (heading, label)|
      response = ApiClient.new.get("/?locale=#{locale}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//main//h1").not_nil!.content.should eq(heading)
      document.xpath_node("//div[@class='latest-release-info']").not_nil!.content.should contain(label)

      response = ApiClient.new.get("/htmx/crystal_latest_release?locale=#{locale}")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//a").not_nil!.content.should eq("#{label} unknown")
    end
  ensure
    ENV["LUCKY_ENV"] = environment if environment
  end

  it "uses the same localized validation message in the field and the failure flash" do
    user = UserFactory.create

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/users/#{user.id}?locale=en&backdoor_user_id=#{user.id}", user: {login_name: "bad name"})
      document = XML.parse_html(response.body)
      expected = "Login name #{Rosetta.find("validations.login_name_format").t}"

      response.status_code.should eq(200)
      document.xpath_node("//div[@class='error']").not_nil!.content.should eq(expected)
      document.xpath_node("//div[contains(@class, 'flash-message--failure')]").not_nil!.content.should contain(expected)
      expected.should_not match(/\p{Han}/)
    end
  end

  it "renders relative timestamps and notification descriptions in the selected locale" do
    user = UserFactory.create
    SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, oauth_provider: "github", created_at: Time.utc - 2.hours)
    response = ApiClient.new.get("/user_audits?locale=en&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main//ol/li/time").not_nil!.content.should eq("about 2 hours ago")
    document.xpath_node("//main//ol/li").not_nil!.content.should contain("Signed in through github.")

    response = ApiClient.new.get("/user_audits?locale=zh-CN&backdoor_user_id=#{user.id}")
    XML.parse_html(response.body).xpath_node("//main//ol/li/time").not_nil!.content.should eq("大约两小时前")
  end

  it "localizes document dates and reading counts with the existing catalog" do
    doc = DocContent.sync("/docs/index", File.read("public/markdowns/index.md"))

    {"en"    => {"Created:", "Last edited:", "1 view", "2 views"},
     "zh-CN" => {"创建于：", "最后编辑于：", "1次阅读", "2次阅读"}}.each do |locale, labels|
      {1, 2}.each do |count|
        SaveDoc.update!(doc, view_count: count)
        response = ApiClient.new.get("/docs/index?locale=#{locale}")
        document = XML.parse_html(response.body)
        metadata = document.xpath_node("//p[@class='doc-page-meta-text']").not_nil!

        response.status_code.should eq(200)
        metadata.xpath_nodes("./time").size.should eq(2)
        metadata.content.should contain(labels[0])
        metadata.content.should contain(labels[1])
        metadata.content.should contain(labels[count + 1])
      end
    end
  end

  it "includes mention guidance in the editor placeholder without a separate footer" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/editor-placeholder", "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    comment = CreateComment.create!(user_id: user.id, comment_thread_id: thread.id, content: "root")

    {"zh-CN" => "最多提及 5 人", "en" => "Mention up to 5 users"}.each do |locale, limit|
      response = ApiClient.new.get("/htmx/comments/new?id=#{comment.id}&locale=#{locale}&backdoor_user_id=#{user.id}")
      document = XML.parse_html(response.body)
      editor = document.xpath_node("//textarea").not_nil!

      response.status_code.should eq(200)
      editor["placeholder"].should contain(limit)
      editor["placeholder"].should contain("@")
      editor["aria-describedby"]?.should be_nil
      document.xpath_node("//*[@id='comment_mention_help']").should be_nil
    end
  end

  it "localizes email subjects and both body formats" do
    user = UserFactory.create

    Rosetta.available_locales.each do |locale|
      Rosetta.with_locale(locale) do
        email = PasswordResetRequestEmail.new(user)
        email.subject.should eq(Rosetta.find("password_reset_request_email.subject").t)
        email.html_body.not_nil!.should contain(Rosetta.find("password_reset_request_email.instructions").t)
        email.html_body.not_nil!.should contain(Rosetta.find("common.reset_password").t)
        email.text_body.not_nil!.should contain(Rosetta.find("password_reset_request_email.instructions").t)
      end
    end
  end

  it "localizes 404 pages even when no normal action was matched" do
    Lucky::ErrorHandler.temp_config(show_debug_output: false) do
      response = ApiClient.new.get("/no-such-page?locale=en")
      response.status_code.should eq(404)
      XML.parse_html(response.body).xpath_node("//h1").not_nil!.content.should eq("Sorry, we couldn't find that page.")
      XML.parse_html(response.body).xpath_node("//html").not_nil!["lang"].should eq("en")
    end
  end

  it "uses the saved locale for errors and falls back for unsupported locales" do
    client = ApiClient.new
    response = client.get("/sign_in?locale=en")
    headers = HTTP::Headers.new
    HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)
    client.headers(Cookie: headers["Cookie"])

    Lucky::ErrorHandler.temp_config(show_debug_output: false) do
      response = client.get("/no-such-page")
      response.status_code.should eq(404)
      XML.parse_html(response.body).xpath_node("//html").not_nil!["lang"].should eq("en")

      response = client.get("/no-such-page?locale=invalid")
      response.status_code.should eq(404)
      document = XML.parse_html(response.body)
      document.xpath_node("//html").not_nil!["lang"].should eq("zh-CN")
      document.xpath_node("//h1").not_nil!.content.should eq("抱歉，找不到这个页面。")
    end
  end

  it "keeps comment HTMX targets as selectors, not translated text" do
    user = UserFactory.create
    pagination = {
      comments: CommentQuery.new,
      page:     nil,
      count:    0_i64,
      url:      "/htmx/comments?comment_thread_id=1",
      order_by: "desc",
    }

    Rosetta.available_locales.each do |locale|
      Rosetta.with_locale(locale) do
        html = Comments::Toolbar.new(pagination: pagination, html_id: "comments", current_user: user).render_to_string
        document = XML.parse_html(html)

        document.xpath_nodes("//a[@hx-target='#comments']").size.should eq(2)
      end
    end
  end
end
