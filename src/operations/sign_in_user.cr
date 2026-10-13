class SignInUser < Avram::Operation
  param_key :user

  attribute login : String
  attribute password : String

  # Run validations and yields the operation and the user if valid
  def run
    user = user_from_login
    validate_credentials(user)

    if valid?
      user
    else
      nil
    end
  end

  private def user_from_login : User?
    value = login.value.to_s.strip

    return nil if value.empty?

    if value.includes?('@')
      UserQuery.new.email(value).first?
    else
      UserQuery.new.with_login_name(value).first?
    end
  end

  # `validate_credentials` determines if a user can sign in.
  #
  # If desired, you can add additional checks in this method, e.g.
  #
  #    if user.locked?
  #      login.add_error "is locked out"
  #    end
  private def validate_credentials(user)
    if user.nil? || !Authentic.correct_password?(user, password.value.to_s)
      login.add_error Rosetta.find("avram.errors.credentials_incorrect").t
    end
  end
end
