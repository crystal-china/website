class Me::ShowPage < MainLayout
  def content
    h1 "This is your profile", class: "mt-10 mb-4 text-[2em] leading-tight font-bold tracking-tight"
    # h3 "Email:  #{@current_user.email}"
    # helpful_tips
  end

  private def helpful_tips
    h3 "Next, you may want to:", class: "mt-6 mb-3 text-[1.17em] leading-snug font-semibold"
    ul do
      li { link_to_authentication_guides }
      li "Modify this page: src/pages/me/show_page.cr"
      li "Change where you go after sign in: src/actions/home/index.cr"
    end
  end

  private def link_to_authentication_guides
    a "Check out the authentication guides",
      href: "https://luckyframework.org/guides/authentication"
  end
end
