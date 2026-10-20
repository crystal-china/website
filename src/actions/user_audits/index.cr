class UserAudits::Index < BrowserAction
  include Lucky::Paginator::BackendHelpers

  param user_id : Int64?

  get "/user_audits" do
    me = current_user
    target_id = user_id

    return head 403 if target_id && target_id != me.id && !me.admin?

    # 只要传入 user_id（哪怕管理员自己, 走个人主页的记录入口，否则管理员后台入口。
    user = if target_id
             target_id == me.id ? me : UserQuery.find(target_id)
           elsif !me.admin?
             me
           end
    query = UserAuditQuery.new.id.desc_order.preload_actor
    query = query.user_id(user.id) if user
    pages, paginated = paginate(query, per_page: 20)
    audits = paginated.results

    if user
      html(
        Me::EventsPage,
        user: user,
        audits: audits,
        pages: pages
      )
    else
      users_by_id = UserQuery.new.id.in(audits.map(&.user_id).uniq!).results.to_h { |account| {account.id, account} }

      html(
        Admin::Events::IndexPage,
        audits: audits,
        users_by_id: users_by_id,
        pages: pages
      )
    end
  end
end
