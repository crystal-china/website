class Me::EditPage < MainLayout
  needs op : UpdateUser
  needs password_changed_at : Time?

  def page_title : String
    "编辑我的信息"
  end

  def content : Nil
    div class: "#{page_container_classes} py-10" do
      mount(
        Shared::UserProfileForm,
        user: current_user.not_nil!,
        op: op,
        update_route: Me::Update.route,
        password_changed_at: password_changed_at,
        current_user: current_user
      )
    end
  end
end
