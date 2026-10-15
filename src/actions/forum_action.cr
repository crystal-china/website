abstract class ForumAction < BrowserAction
  expose nodes

  private def nodes : Array(Node)
    NodeQuery.new.sorted.results
  end
end
