class AppServer < Lucky::BaseAppServer
  # Learn about middleware with HTTP::Handlers:
  # https://luckyframework.org/guides/http-and-routing/http-handlers
  def middleware : Array(HTTP::Handler)
    [
      Lucky::RequestIdHandler.new,
      Lucky::ForceSSLHandler.new,
      Lucky::HttpMethodOverrideHandler.new,
      Lucky::LogHandler.new,
      Lucky::ErrorHandler.new(action: Errors::Show),
      Lucky::RemoteIpHandler.new,
      Lucky::RouteHandler.new,
      Lucky::StaticCompressionHandler.new("./dist", file_ext: "br", content_encoding: "br"),
      Lucky::StaticCompressionHandler.new("./dist", file_ext: "gz", content_encoding: "gzip"),
      Lucky::StaticFileHandler.new("./dist", fallthrough: false, directory_listing: false),
      LuckyEnv.production? ? Lucky::StaticFileHandler.new("./public", fallthrough: false, directory_listing: false) : nil,
      Lucky::RouteNotFoundHandler.new,
    ].select(HTTP::Handler)
  end

  def protocol
    "http"
  end

  def listen
    server.listen(host, port, reuse_port: false)
  end
end
