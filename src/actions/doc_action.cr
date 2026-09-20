abstract class DocAction < BrowserAction
  include Auth::AllowGuests
  include MarkdownFormatter
  include PageHelpers

  expose formatter
end
