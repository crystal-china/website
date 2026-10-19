# Generates and decodes JSON Web Tokens for Authenticating users.
class UserToken
  Habitat.create { setting stubbed_token : String? }
  ALGORITHM  = JWT::Algorithm::HS256
  AUDIENCE   = "crystal-china-api"
  ISSUER     = "crystal-china"
  EXPIRES_IN = 7.days

  def self.generate(user : User) : String
    now = Time.utc
    payload = {
      "user_id"         => user.id,
      "session_version" => user.session_version,
      "iat"             => now.to_unix,
      "exp"             => (now + EXPIRES_IN).to_unix,
      "aud"             => AUDIENCE,
      "iss"             => ISSUER,
    }

    settings.stubbed_token || create_token(payload)
  end

  def self.create_token(payload) : String
    JWT.encode(
      payload,
      Lucky::Server.settings.secret_key_base,
      ALGORITHM
    )
  end

  def self.decode_user(token : String) : User?
    payload, _header = JWT.decode(
      token,
      Lucky::Server.settings.secret_key_base,
      ALGORITHM,
      aud: AUDIENCE,
      iss: ISSUER
    )
    user_id = payload["user_id"]?.try(&.as_i64?)
    version = payload["session_version"]?.try(&.as_s?)

    return nil unless user_id && version

    UserQuery.new.id(user_id).session_version(version).first?
  rescue e : JWT::Error
    Lucky::Log.dexter.error { {jwt_decode_error: e.message} }
    nil
  end

  def self.decode_user_id(token : String) : Int64?
    decode_user(token).try(&.id)
  end

  # Used in tests to return a fake token to test against.
  def self.stub_token(token : String, &) : String?
    temp_config(stubbed_token: token) do
      yield
    end
  end
end
