class UserFactory < Avram::Factory
  def initialize
    nickname sequence("Nickname")
    login_name sequence("LoginName")
    email "#{sequence("test-email")}@example.com"
    encrypted_password Authentic.generate_encrypted_password("password")
  end
end
