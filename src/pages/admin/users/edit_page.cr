class Admin::Users::EditPage < AdminLayout
  needs user : User
  needs op : UpdateUser
  needs password_changed_at : Time?

  def page_title : String
    "编辑 #{user.nickname} 的个人资料"
  end

  def admin_content : Nil
    mount(
      Shared::UserProfileForm,
      user: user,
      op: op,
      update_route: Admin::Users::Update.with(id: user.id),
      password_changed_at: password_changed_at,
      current_user: current_user
    )
  end
end
