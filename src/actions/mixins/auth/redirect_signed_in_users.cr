module Auth::RedirectSignedInUsers
  macro included
    include Auth::AllowGuests
    before redirect_signed_in_users
  end

  private def redirect_signed_in_users : Lucky::Response | Lucky::ActionPipes::Continue
    if current_user?
      flash.success = r("auth.redirect_signed_in_users.already_signed_in").t
      redirect to: Home::Index
    else
      continue
    end
  end

  # current_user returns nil because signed in users are redirected.
  def current_user : Nil
  end
end
