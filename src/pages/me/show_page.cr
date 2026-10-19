class Me::ShowPage < MainLayout
  def content : Nil
    h1 r(".page_title").t, class: "mt-10 mb-4 text-[2em] leading-tight font-bold tracking-tight"
    # h3 "Email:  #{@current_user.email}"
    # helpful_tips
  end

  private def helpful_tips : Nil
    h3 r(".next_steps").t, class: "mt-6 mb-3 text-[1.17em] leading-snug font-semibold"
    ul do
      li { link_to_authentication_guides }
      li r(".modify_page").t
      li r(".after_sign_in").t
    end
  end

  private def link_to_authentication_guides : Nil
    a(
      r(".auth_guides").t,
      href: "https://luckyframework.org/guides/authentication"
    )
  end
end
