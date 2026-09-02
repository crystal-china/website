class Home::Htmx::CrystalLatestRelease < BrowserAction
  include Auth::AllowGuests

  LATEST_RELEASE_CACHE_KEY = "latest_version"
  UNKNOWN_VERSION          = "unknown"

  get "/htmx/crystal_latest_release" do
    version = LATEST_RELEASE_CACHE.read(LATEST_RELEASE_CACHE_KEY) || latest_release_version
    plain_text <<-HTML
      <div class="latest-release-info">
        <a href="https://crystal-lang.org/">Latest release: <strong>#{version}</strong></a>
      </div>
    HTML
  end

  private def latest_release_version
    return UNKNOWN_VERSION if LuckyEnv.development?

    HTTP::Client.new("crystal-lang.org", tls: true) do |client|
      # client.connect_timeout = 3.seconds
      # client.read_timeout = 5.seconds
      res = client.get("/")

      if res.success?
        if (match_data = res.body.match(%r{<div class="latest-release-info">(.+?)</div>}m))
          if (release = match_data[1]?)
            if version = release[/Latest release:\D*([0-9.]+)/, 1]?
              return LATEST_RELEASE_CACHE.write(LATEST_RELEASE_CACHE_KEY, version)
            end
          end
        end
      end
    end

    UNKNOWN_VERSION
  rescue Socket::ConnectError | IO::TimeoutError
    UNKNOWN_VERSION
  end
end
