class SignUpUser < User::SaveOperation
  param_key :user
  # Change password validations in src/operations/mixins/password_validations.cr
  include PasswordValidations

  permit_columns email
  attribute password : String
  attribute password_confirmation : String
  attribute captcha_code : String

  before_save do
    validate_uniqueness_of email
    validate_required captcha_code
    Authentic.copy_and_encrypt(password, to: encrypted_password) if password.valid?

    while (user_name = "User#{rand(100000..999999)}")
      if UserQuery.new.name(user_name).none?
        self.name.value = user_name
        break
      end
    end
    validate_username
  end
end
