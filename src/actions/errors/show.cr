# This class handles error responses and reporting.
#
# https://luckyframework.org/guides/http-and-routing/error-handling
class Errors::Show < Lucky::ErrorAction
  include Rosetta::Translatable

  default_format :html
  dont_report [Lucky::RouteNotFoundError, Avram::RecordNotFoundError]

  def perform_action(error : Exception) : Nil
    # 路由未匹配时不会经过 BrowserAction 的 set_locale。
    locale = params.get?(:locale) || session.get?(:locale) || Rosetta.default_locale
    locale = Rosetta.default_locale unless locale.in?(Rosetta.available_locales)

    Rosetta.with_locale(locale) { super(error) }
  end

  def render(error : Lucky::RouteNotFoundError | Avram::RecordNotFoundError) : Lucky::Response
    if html?
      error_html r(".not_found").t, status: 404
    else
      error_json r(".not_found_json").t, status: 404
    end
  end

  # When the request is JSON and an InvalidOperationError is raised, show a
  # helpful error with the param that is invalid, and what was wrong with it.
  def render(error : Avram::InvalidOperationError) : Lucky::Response
    if html?
      error_html r(".default_error").t, status: 500
    else
      error_json(
        message: error.renderable_message,
        details: error.renderable_details,
        param: error.invalid_attribute_name,
        status: 400
      )
    end
  end

  # Always keep this below other 'render' methods or it may override your
  # custom 'render' methods.
  def render(error : Lucky::RenderableError) : Lucky::Response
    if html?
      error_html r(".default_error").t, status: error.renderable_status
    else
      error_json error.renderable_message, status: error.renderable_status
    end
  end

  # If none of the 'render' methods return a response for the raised Exception,
  # Lucky will use this method.
  def default_render(error : Exception) : Lucky::Response
    if html?
      error_html r(".default_error").t, status: 500
    else
      error_json r(".default_error").t, status: 500
    end
  end

  private def error_html(message : String, status : Int) : Lucky::Response
    context.response.status_code = status
    html_with_status(
      Errors::ShowPage,
      status,
      message: message,
      status_code: status
    )
  end

  private def error_json(message : String, status : Int, details = nil, param = nil) : Lucky::Response
    json(
      ErrorSerializer.new(
        message: message,
        details: details,
        param: param
      ),
      status: status
    )
  end

  private def report(error : Exception) : Nil
    Lucky::Log.error(exception: error) { "" }
    # Send to Rollbar, send an email, etc.
  end
end
