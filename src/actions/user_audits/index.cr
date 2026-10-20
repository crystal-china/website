class UserAudits::Index < BrowserAction
  include Lucky::Paginator::BackendHelpers

  param user_id : Int64?
  param login_name : String = ""
  param kind : String = ""

  get "/user_audits" do
    me = current_user
    target_id = user_id
    selected_kind = nil

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
      selected_kind = UserAudit::Kind.parse?(kind)

      return head 400 if !kind.empty? && selected_kind.nil?

      query = query.preload_user
      query = query.join_user(UserQuery.new.with_login_name(login_name)) unless login_name.empty?
      query = query.kind(selected_kind) if selected_kind
    end

    pages, audits = paginate(query, per_page: 20)

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        UserAudits::List,
        audits: audits.results,
        pages: pages,
        show_account: user.nil?,
        current_user: me
      )
    end

    html(
      UserAudits::IndexPage,
      user: user,
      audits: audits.results,
      pages: pages,
      login_name: login_name,
      kind: selected_kind
    )
  end
end
