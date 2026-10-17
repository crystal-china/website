require "./main_layout"

abstract class AuthLayout < MainLayout
  include AuthPageHelpers

  def page_title : String
    r("auth_layout.page_title").t
  end
end
