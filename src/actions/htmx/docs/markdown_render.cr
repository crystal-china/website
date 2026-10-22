class Htmx::Markdown::Preview < BrowserAction
  include Auth::AllowGuests
  include MarkdownFormatter
  include PageHelpers

  param content : String

  put "/htmx/docs/markdown_render" do
    return head 401 if current_user.nil?
    return head 400 if content.blank?

    plain_text user_markdown(content)
  end
end
