require "timecop"
require "../spec_helper"

describe UserToken do
  it "expires tokens seven days after they are issued" do
    user = UserFactory.create
    issued_at = Time.utc
    token = Timecop.freeze(issued_at) { UserToken.generate(user) }

    payload, _header = JWT.decode(
      token,
      Lucky::Server.settings.secret_key_base,
      UserToken::ALGORITHM,
      aud: UserToken::AUDIENCE,
      iss: UserToken::ISSUER
    )

    payload["iat"].as_i64.should eq(issued_at.to_unix)
    payload["exp"].as_i64.should eq((issued_at + 7.days).to_unix)

    Timecop.freeze(issued_at + 7.days + 1.second) do
      UserToken.decode_user_id(token).should be_nil
    end
  end
end
