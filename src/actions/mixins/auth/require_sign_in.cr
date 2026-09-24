module Auth::RequireSignIn
  macro included
    before require_sign_in
  end

  private def require_sign_in
    if current_user?
      continue
    elsif context.request.headers["HX-Request-Type"]? == "partial"
      head 401
    else
      Authentic.remember_requested_path(self)
      flash.info = "请首先登录"
      redirect to: SignIns::New
    end
  end

  # Tells the compiler that the current_user is not nil since we have checked
  # that the user is signed in
  private def current_user : User
    current_user?.as(User)
  end
end
