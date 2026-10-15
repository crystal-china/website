class Me::Events < BrowserAction
  include Lucky::Paginator::BackendHelpers

  param user_id : Int64?

  get "/me/events" do
    user = current_user

    if (id = user_id) && id != user.id
      return head 403 unless user.admin?

      user = UserQuery.find(id)
    end

    query = UserAuditQuery.new.user_id(user.id).id.desc_order
    pages, audits = paginate(query, per_page: 20)

    html Me::EventsPage, user: user, audits: audits.results, pages: pages
  end
end
