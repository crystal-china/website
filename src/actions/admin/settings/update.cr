class Admin::Settings::Update < AdminAction
  # 只保存并重绘站点信息表单，保留邮件 Tab 尚未提交的输入。
  put "/admin/settings" do
    space = context.site_space.not_nil!

    context.response.headers["HX-Push-Url"] = "false"

    UpdateSpaceSettings.update(space, params) do |operation, updated_space|
      if operation.saved?
        flash.success = r(".settings_updated").t
        operation = UpdateSpaceSettings.new(updated_space.not_nil!)
      else
        build_failed_flash(operation)
      end

      component(
        Admin::Settings::SiteForm,
        operation: operation,
        flash: flash
      )
    end
  end
end
