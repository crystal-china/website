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
    # 原表单有隐藏字段 return_to, 浏览器提交表单时，它和用户名一起发送
    # 验证失败，Action 直接渲染编辑页, 编辑页使用的 context，仍然是刚才这次 PUT 请求的 context
    source = context.params.get?(:return_to) || context.request.headers["Referer"]?

    ReturnPath.parse(source) || Users::Show.with(login_name: user.login_name).path
  end
end
