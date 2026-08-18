# Add methods that all or most Flows need to share
class BaseFlow < LuckyFlow
  def js_eval(script : String, args : Array(String) = [] of String)
    driver.as(LuckyFlow::Selenium::Driver).execute_script(script, args)
  end

  def js_bool(script : String, args : Array(String) = [] of String) : Bool
    js_eval(script, args) == "true"
  end

  def dom_click(css_selector : String)
    js_eval(
      <<-JS,
        const element = document.querySelector(arguments[0]);
        if (element) element.click();
      JS
      [css_selector]
    )
  end
end

abstract class LuckyFlow::Selenium::Driver
  def execute_script(script : String, args : Array(String) = [] of String)
    session.document_manager.execute_script(script, args)
  end
end
