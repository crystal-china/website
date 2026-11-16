class Admin::Settings::Edit < AdminAction
  get "/admin/settings" do
    space = context.site_space.not_nil!

    html(
      Admin::Settings::EditPage,
      site_operation: UpdateSpaceSettings.new(space),
      mail_operation: UpdateMailSettings.new(space)
    )
  end
end
