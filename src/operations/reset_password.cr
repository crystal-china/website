class ResetPassword < User::SaveOperation
  # Change password validations in src/operations/mixins/password_validations.cr
  include PasswordValidations

  attribute password : String
  attribute password_confirmation : String

  before_save do
    Authentic.copy_and_encrypt password, to: encrypted_password if password.valid?
  end

  after_save do |user|
    if encrypted_password.changed?
      SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::PasswordChanged)
    end
  end
end
