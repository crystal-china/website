require "./main_layout"

abstract class AuthLayout < MainLayout
  include AuthPageHelpers

  def page_title
    "欢迎"
  end
end
