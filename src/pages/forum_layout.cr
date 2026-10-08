require "./main_layout"

abstract class ForumLayout < MainLayout
  private def search_scope : String?
    "topics"
  end
end
