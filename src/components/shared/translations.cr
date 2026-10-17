class Shared::Translations < BaseComponent
  def render : Nil
    script type: "application/json", id: "i18n-messages" do
      raw messages.to_json.gsub("<", "\\u003c")
    end
  end

  private def messages : Hash(String, String)
    {
      "tip"                => r("javascript.tip").t,
      "invalid_request"    => r("javascript.invalid_request").t,
      "sign_in_required"   => r("javascript.sign_in_required").t,
      "forbidden"          => r("javascript.forbidden").t,
      "not_found"          => r("javascript.not_found").t,
      "conflict"           => r("javascript.conflict").t,
      "server_error"       => r("javascript.server_error").t,
      "offline"            => r("javascript.offline").t,
      "timeout"            => r("javascript.timeout").t,
      "connection_failed"  => r("javascript.connection_failed").t,
      "interaction_failed" => r("javascript.interaction_failed").t,
      "file_too_large"     => r("javascript.file_too_large").t(size: "%{size}"),
      "upload_failed"      => r("javascript.upload_failed").t(message: "%{message}"),
      "upload_error"       => r("javascript.upload_error").t,
      "mention_users"      => r("javascript.mention_users").t,
      "copy"               => r("javascript.copy").t,
      "copied"             => r("javascript.copied").t,
    }
  end
end
