class RequestPasswordReset < Avram::Operation
  # You can modify this in src/operations/mixins/user_from_email.cr
  include UserFromEmail

  attribute email : String

  # Run validations and yield the operation and the user if valid
  def run : User?
    user = user_from_email
    validate(user)

    user if valid?
  end

  def validate(user : User?) : Nil
    validate_required email
    if user.nil?
      email.add_error r("validations.email_not_registered").t
    end
  end
end
