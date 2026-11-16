class Admin::Settings::EditPage < AdminLayout
  needs site_operation : UpdateSpaceSettings
  needs mail_operation : UpdateMailSettings

  def page_title : String
    r("common.site_settings").t
  end

  def admin_content : Nil
    show_site_settings_tab_script = <<-HYPER
on click
  set #site-settings-panel.hidden to false
  set #mail-settings-panel.hidden to true
  set #site-settings-tab.dataset.active to true
  set #mail-settings-tab.dataset.active to false
end
HYPER
    show_mail_settings_tab_script = <<-HYPER
on click
  set #site-settings-panel.hidden to true
  set #mail-settings-panel.hidden to false
  set #site-settings-tab.dataset.active to false
  set #mail-settings-tab.dataset.active to true
end
HYPER
    settings_tab_classes = "rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 data-[active=true]:bg-white data-[active=true]:text-gray-900 data-[active=true]:shadow-sm"

    section class: "app-panel w-full max-w-3xl overflow-hidden" do
      nav class: "flex gap-1 border-b border-gray-200 bg-gray-50 p-2" do
        button(
          r(".branding").t,
          type: "button",
          id: "site-settings-tab",
          data_active: "true",
          class: settings_tab_classes,
          script: show_site_settings_tab_script
        )
        button(
          r(".mail").t,
          type: "button",
          id: "mail-settings-tab",
          data_active: "false",
          class: settings_tab_classes,
          script: show_mail_settings_tab_script
        )
      end

      # 两个表单一直保留在页面中；切换和保存都不重建另一个 Tab。
      div id: "site-settings-panel" do
        mount Admin::Settings::SiteForm, operation: site_operation
      end

      div id: "mail-settings-panel", hidden: true do
        mount Admin::Settings::MailForm, operation: mail_operation
      end
    end
  end
end
