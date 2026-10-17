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
        password_changed_at: password_changed_at,
        current_user: current_user
      )
    end
  end
end
