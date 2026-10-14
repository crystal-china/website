require "../spec_helper"

private class UserMarkdownHarness
  include PageHelpers

  getter formatter = Tartrazine::Html.new(
    theme: Tartrazine.theme("catppuccin-macchiato"),
    line_numbers: true,
    standalone: false,
  )
end

describe UserHtmlSanitizer do
  renderer = UserMarkdownHarness.new

  it "removes scripts, event handlers, unsafe URLs, styles, and unknown classes" do
    html = renderer.user_markdown(<<-MARKDOWN)
    <script>alert("script")</script>
    <img src="avatar.png" onerror="alert('image')">
    <a href="javascript:alert('link')">unsafe link</a>
    <span class="hidden" style="position: fixed">styled text</span>
    MARKDOWN

    html.should_not contain("<script")
    html.should_not contain("onerror")
    html.should_not contain("javascript:")
    html.should_not contain("position: fixed")
    html.should_not contain("class=\"hidden\"")
    html.should contain("unsafe link")
    html.should contain("styled text")
  end

  it "preserves safe Markdown and safe links" do
    html = renderer.user_markdown("**strong** [Crystal](https://crystal-lang.org)")

    html.should contain("<strong>strong</strong>")
    html.should contain(%(href="https://crystal-lang.org"))
    html.should contain(%(rel="nofollow"))
  end

  it "preserves info callouts and syntax highlighting" do
    html = renderer.user_markdown(<<-MARKDOWN)
    ```info
    callout body

    # callout heading
    ```

    ```crystal
    puts "hello"
    ```
    MARKDOWN

    html.should contain(%(class="box info"))
    html.should contain(%(class="titlebar block"))
    html.should contain("<h1>callout heading</h1>")
    html.should_not contain("#anchor-")
    html.should contain(%(<pre class="b">))
    html.should contain(%(style="user-select: none;"))
  end

  it "links valid mentions without requiring an existing user or changing the source" do
    content = "谢谢 @_zw_963，感谢你_。还有 @a_b_c、@Some.User-23 和 @Crystalist_123456。"
    original = content.dup
    html = renderer.user_markdown(content)

    ["_zw_963", "a_b_c", "Some.User-23", "Crystalist_123456"].each do |login_name|
      html.should contain(%(href="/users/#{login_name}/profile"))
      html.should contain(">@#{login_name}</a>")
    end
    content.should eq(original)
  end

  it "preserves formatting and punctuation around mentions" do
    html = renderer.user_markdown("**@zw963** _@a_b_c_ @some.user. @zw963 @zw963")

    html.should contain(%(<strong><a href="/users/zw963/profile"))
    html.should contain(%(<em><a href="/users/a_b_c/profile"))
    html.should contain(">@some.user</a>.")
    html.scan(%(href="/users/zw963/profile")).size.should eq(3)
  end

  it "links mentions next to Chinese text or after an underscore" do
    ["@zw963中文", "hello_@zw963", "_@zw963_"].each do |content|
      html = renderer.user_markdown(content)

      html.should contain(%(href="/users/zw963/profile"))
      html.should contain(">@zw963</a>")
    end
  end

  it "does not link mentions in code, existing links, images, or raw HTML links" do
    html = renderer.user_markdown(<<-MARKDOWN)
    `@_zw_963`

    ```crystal
    puts "@_zw_963"
    ```

    [@_zw_963](https://example.com/@_zw_963)
    ![@_zw_963](https://example.com/@_zw_963.png)
    <a href="https://example.com">@_zw_963</a>
    <code>@_zw_963</code>
    MARKDOWN

    html.should_not contain("/users/")
    html.should_not contain("USERMENTIONTOKEN")
    html.should contain("<code>@_zw_963</code>")
    html.should contain(%(href="https://example.com/@_zw_963"))
    html.should contain(%(alt="@_zw_963"))
    html.should contain(%(src="https://example.com/@_zw_963.png"))
  end

  it "does not link invalid handles, emails, or partial usernames" do
    html = renderer.user_markdown("@a__b @a._b @abcdefghijklmnopqrstu test@some.user @zw963@example.com @x")

    html.should_not contain("/users/")
  end

  it "keeps literal placeholder-like text and displays callout mentions without links" do
    html = renderer.user_markdown("USERMENTIONTOKEN0END\n\n```info\n谢谢 @zw963\n```")

    html.should contain("USERMENTIONTOKEN0END")
    html.should contain(%(class="box info"))
    html.should contain("@zw963")
    html.should_not contain(%(href="/users/zw963/profile"))
  end

  it "links only the first five distinct handles and permits repeated mentions" do
    content = "@Person5 @PERSON5 @Person4 @Person3 @Person2 @Person1 @Person0 @Person5"
    html = renderer.user_markdown(content)
    ["Person5", "PERSON5", "Person4", "Person3", "Person2", "Person1"].each do |login_name|
      html.should contain(%(href="/users/#{login_name}/profile"))
    end
    html.should_not contain(%(href="/users/Person0/profile"))
    html.should contain("@Person0")
    html.scan(%(href="/users/Person5/profile")).size.should eq(2)
  end
end

describe "Documentation Markdown" do
  renderer = UserMarkdownHarness.new

  it "renders info callouts inside blockquotes" do
    html = renderer.doc_markdown(<<-MARKDOWN)
    > ```info
    > **callout body** @zw963
    > ```
    MARKDOWN

    html.should contain("<blockquote>")
    html.should contain(%(class="box info"))
    html.should contain("<strong>callout body</strong>")
    html.should contain("@zw963")
    html.should_not contain("/users/")
  end

  it "leaves info examples inside longer code fences unchanged" do
    html = renderer.doc_markdown(<<-MARKDOWN)
    ````
    ```info
    example body
    ```
    ````
    MARKDOWN

    html.should contain("<pre><code>")
    html.should contain("```info\nexample body\n```")
    html.should_not contain(%(class="box info"))
  end

  it "preserves documentation heading anchors and trusted HTML" do
    html = renderer.doc_markdown("# Heading\n\n<div data-table-scheduler></div>")

    html.should contain("#anchor-Heading")
    html.should contain(%(<div data-table-scheduler></div>))
  end
end
