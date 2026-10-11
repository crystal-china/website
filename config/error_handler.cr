Lucky::ErrorHandler.configure do |settings|
  settings.show_debug_output = !LuckyEnv.production?
  # Errors::Show reports exceptions so dont_report also suppresses expected 404 backtraces.
  settings.log_error_exception = false
end
