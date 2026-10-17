class Users::EditPage < MainLayout
  needs user : User
  needs op : UpdateUser
  needs password_changed_at : Time?

  def page_title : String
    r(".page_title").t(nickname: user.nickname)
  end

  def content : Nil
    div class: "#{page_container_classes} py-10" do
      mount(
        Shared::UserProfileForm,
        user: user,
        op: op,
        return_path: return_path,
        password_changed_at: password_changed_at,
        current_user: current_user
      )
    end
  end

  private def return_path : String
    # 校验失败时保留表单中的最初来源，不重新读取指向编辑页的 Referer。
    source = context.params.get?(:return_to) || context.request.headers["Referer"]?

    ReturnPath.parse(source) || Users::Show.with(login_name: user.login_name).path
  end
end
