module PasswordValidations
  MIN_PASSWORD_LENGTH = 6
  # BCrypt only supports passwords up to 72 bytes.
  MAX_PASSWORD_LENGTH = 72

  macro included
    before_save run_password_validations
  end

  private def run_password_validations
    validate_required password, password_confirmation
    validate_confirmation_of password, with: password_confirmation
    validate_size_of password,
      min: PasswordValidations::MIN_PASSWORD_LENGTH,
      max: PasswordValidations::MAX_PASSWORD_LENGTH
  end
end
