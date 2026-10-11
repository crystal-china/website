module NotificationHelpers
  include Lucky::Paginator::BackendHelpers

  private def render_notifications
    query = NotificationQuery.new.user_id(current_user.id)
    pages = Lucky::Paginator.new(
      page: paginator_page,
      per_page: 20,
      item_count: query.select_count,
      # GET 和 POST 都返回列表，分页始终请求读取列表的 GET 路由。
      # 如果使用 paginate 方法，会使用当前请求地址 full_path: context.request.resource
      # 这这对 read_all, 会 GET /notifications/read_all?page=2, 这是错误的。
      # 因此，固定使用通知列表地址
      full_path: Notifications::Index.path
    )
    notifications = query.id.desc_order.preload_actor.limit(pages.per_page).offset(pages.offset)

    component(
      ::Notifications::List,
      notifications: notifications,
      pages: pages,
      current_user: current_user
    )
  end
end
