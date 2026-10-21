abstract class ForumAction < BrowserAction
  expose nodes

  private def nodes : Array(Node)
    NodeQuery.new.sorted.results
  end

  private def redirect_after_save(topic : Topic) : Lucky::Response
    path = Forum::Show.with(id: topic.id).path

    if context.request.headers["HX-Request-Type"]?
      # HTTP 重定向会丢失中间响应头；让 HTMX 先清理草稿，再进入详情页。
      flash.keep
      context.response.headers["X-Draft-Saved"] = "true"
      context.response.headers["HX-Location"] = path

      head 200
    else
      redirect to: path
    end
  end
end
