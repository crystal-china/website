class Admin::Settings::UpdateMail < AdminAction
  # 只保存并重绘邮件表单，保留站点信息 Tab 尚未提交的输入。
  put "/admin/settings/mail" do
    space = context.site_space.not_nil!

    context.response.headers["HX-Push-Url"] = "false"

    UpdateMailSettings.update(space, params) do |operation, updated_space|
      if operation.saved?
        BaseEmail.configure_smtp(updated_space.not_nil!)

        flash.success = r("admin.settings.update.settings_updated").t
        # 使用新的 Operation 显示保存结果，同时清空密码输入和清除选项。
        operation = UpdateMailSettings.new(updated_space.not_nil!)
      else
        build_failed_flash(operation)
      end

      component(
        Admin::Settings::MailForm,
        operation: operation,
        flash: flash
      )
    end
  end
end
