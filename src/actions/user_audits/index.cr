class UserAudits::Index < BrowserAction
  include Lucky::Paginator::BackendHelpers

  param user_id : Int64?

  get "/user_audits" do
    me = current_user
    target_id = user_id

    return head 403 if target_id && target_id != me.id && !me.admin?

    # 传入 user_id 时查看指定账户（包括管理员本人）；管理员不传时查看全站。
    user = if target_id
             target_id == me.id ? me : UserQuery.find(target_id)
           elsif !me.admin?
             me
           end
    query = UserAuditQuery.new.id.desc_order.preload_actor

    if user
      query = query.user_id(user.id)
    else
      query = query.preload_user
    end

    pages, audits = paginate(query, per_page: 20)

    html(
      UserAudits::IndexPage,
      user: user,
      audits: audits.results,
      pages: pages
    )
  end
end
