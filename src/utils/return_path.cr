require "uri"

module ReturnPath
  def self.parse(source : String?) : String?
    return if source.nil? || source.empty?

    uri = URI.parse(source)

    return unless uri.scheme.nil? || uri.scheme.in?({"http", "https"})
    unless uri.path.starts_with?("/") && !uri.path.starts_with?("//") && !uri.path.includes?('\\')
      return
    end

    uri.request_target
  rescue URI::Error
    nil
  end
end
