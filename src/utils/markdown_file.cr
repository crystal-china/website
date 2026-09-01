module MarkdownFile
  ROOT = Path["markdowns"].normalize

  def self.resolve(request_path : String?) : String?
    return unless request_path

    requested = Path[request_path]
    return if requested.absolute?

    candidate = ROOT.join("#{request_path}.md").normalize
    relative = candidate.relative_to?(ROOT)
    return if relative.nil? || relative.parts.first? == ".."
    return unless File.file?(candidate)

    candidate.to_s
  end
end
