require "digest/md5"

module DocContent
  def self.sync(doc : Doc, source : String, updated_at : Time = Time.utc) : Doc
    digest = Digest::MD5.hexdigest(source)
    return doc if doc.content_digest == digest && doc.content_updated_at

    SaveDoc.update!(
      doc,
      content_digest: digest,
      content_updated_at: updated_at
    )
  end
end
