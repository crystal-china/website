class Comments::Thread < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs root_comment : Comment
  needs order_by : String
  # 根评论下面的子评论分页（二级分页），不是主评论区分页；首次折叠时为 nil。
  needs pagination : Comments::Pagination? = nil
  needs comment_id : Int64? = nil
  needs focused_comment_id : Int64? = nil

  def render : Nil
    # 首次显示不查询回复；新增／删除复用现成分页，通知定位时才自动加载目标页。
    div(
      id: "comment-#{root_comment.id}-thread",
      class: "comment-thread"
    ) do
      if (pages = pagination)
        # 已有子分页：新增／删除子评论后，ChildCreated／Deleted 把 Action 准备好的子分页传到这里。
        # 例如给根评论 A 新增回复 B，直接显示更新后的回复列表和 toggle，不再发一次加载请求。
        # 删除最后一条回复也进入这个分支，只是 count 为 0，下面会输出空容器。
        if pages[:count] > 0
          render_thread_toggle(expanded: true)

          mount(
            Comments::List,
            formatter: formatter,
            pagination: pages,
            html_id: "comment-#{root_comment.id}-comments",
            comment_id: comment_id,
            current_user: current_user
          )
        else
          # 删除最后一条回复后，保留空容器，toggle 自动隐藏。
          render_thread_toggle(expanded: false)

          div id: "comment-#{root_comment.id}-comments"
        end
      elsif (focus_id = focused_comment_id)
        # 需要定位：通过通知或评论链接跳转到子评论时，外层已找到根评论，但尚未准备它的子分页。
        # 例如目标是 A 下面的评论 123，这里收到 focused_comment_id = 123，先显示加载提示。
        # 容器出现后，hx_trigger: "load" 自动请求 Htmx::Comments::Index，由它定位并返回 123 所在的分页。
        render_thread_toggle(expanded: true)

        div(
          id: "comment-#{root_comment.id}-comments",
          hx_get: Htmx::Comments::Index.with(
            root_id: root_comment.id,
            comment_id: focus_id,
            order_by: order_by
          ).path,
          hx_trigger: "load",
          hx_swap: "outerHTML"
        ) do
          mount Shared::Spinner, text: r("comments.card.locating_comment").t
        end
      else
        # 其他情况：普通打开文档／主题评论区，或刷新主评论列表时，没有子分页，也没有子评论定位目标。
        # 例如 A 已有 20 条回复，先保持折叠，不查询这些回复；数量从 descendants_count 读取。
        # 用户点击展开按钮后才发请求加载内部列表，不会重新渲染整个 Thread。
        render_thread_toggle(expanded: false)

        div id: "comment-#{root_comment.id}-comments"
      end
    end
  end

  private def render_thread_toggle(*, expanded : Bool) : Nil
    mount(
      Comments::ThreadToggle,
      comment: root_comment,
      order_by: order_by,
      expanded: expanded,
      current_user: current_user
    )
  end
end
