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
end
