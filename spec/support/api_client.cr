class ApiClient < Lucky::BaseHTTPClient
  app AppServer.new

  def initialize
    super
    headers("Content-Type": "application/json")
  end

  def self.auth(user : User) : self
    new.headers("Authorization": UserToken.generate(user))
  end
end
