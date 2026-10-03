class Notifications::Index < BrowserAction
  include Lucky::Paginator::BackendHelpers

  get "/notifications" do
    query = NotificationQuery.new.user_id(current_user.id).id.desc_order.for_display
    pages, notifications = paginate(query, per_page: 20)

    html Notifications::IndexPage, notifications: notifications, pages: pages
  end
end
