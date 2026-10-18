def time_zone_context(value : String? = nil) : HTTP::Server::Context
  headers = HTTP::Headers.new
  headers["Cookie"] = "time_zone=#{value}" if value

  HTTP::Server::Context.new(
    HTTP::Request.new("GET", "/", headers),
    HTTP::Server::Response.new(IO::Memory.new)
  )
end
