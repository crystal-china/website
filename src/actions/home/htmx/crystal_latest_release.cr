class Home::Htmx::CrystalLatestRelease < BrowserAction
  include Auth::AllowGuests

  UNAVAILABLE_RESULT = <<-'HEREDOC'
<div class="latest-release-info">
      <a href="https://crystal-lang.org/">Latest release: <strong>unknown</strong></a>
</div>
HEREDOC

  get "/htmx/crystal_latest_release" do
    plain_text LATEST_RELEASE_CACHE.fetch("current") { latest_release_result }
  end

  private def latest_release_result
    return UNAVAILABLE_RESULT if LuckyEnv.development?

    HTTP::Client.new("crystal-lang.org", tls: true) do |client|
      client.connect_timeout = 3.seconds
      client.read_timeout = 5.seconds
      res = client.get("/")

      if res.success?
        match_data = res.body.match(%r{<div class="latest-release-info">.+?</div>}m)
        return match_data.to_s.sub(/href="(.+)?"/, "href=\"https://crystal-lang.org\\1\"") if match_data
      end
    end

    UNAVAILABLE_RESULT
  rescue Socket::ConnectError | IO::TimeoutError
    # Report the unavailable state instead of returning a potentially stale version.
    UNAVAILABLE_RESULT
  end
end
