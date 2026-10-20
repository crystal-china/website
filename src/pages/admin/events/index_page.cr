class Admin::Events::IndexPage < AdminLayout
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator

  def page_title : String
    r("common.events").t
  end

  def admin_content : Nil
    header class: "mb-6" do
      h2 page_title, class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
      para r(".description").t, class: "mt-1.5 mb-0 text-sm text-gray-600"
    end

    section class: "app-panel overflow-hidden" do
      mount(
        UserAudits::List,
        audits: audits,
        show_account: true,
        pages: pages
      )
    end
  end
end
