module Auth::RedirectSignedInUsers
  macro included
    include Auth::AllowGuests
    before redirect_signed_in_users
  end

  private def redirect_signed_in_users : Lucky::Response | Lucky::ActionPipes::Continue
    if current_user?
      flash.success = "您已经登录"
      redirect to: Home::Index
    else
      continue
    end
  end

  # current_user returns nil because signed in users are redirected.
  def current_user : Nil
  end
end
