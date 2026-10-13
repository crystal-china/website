class SignUpUser < User::SaveOperation
  param_key :user
  # Change password validations in src/operations/mixins/password_validations.cr
  include PasswordValidations
  include UserNameValidations

  permit_columns email, nickname, login_name
  attribute password : String
  attribute password_confirmation : String
  attribute captcha_code : String

  before_save do
    validate_uniqueness_of email
    validate_required captcha_code
    validate_user_names
    Authentic.copy_and_encrypt(password, to: encrypted_password) if password.valid?
  end
end
