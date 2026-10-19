require "digest/md5"

module DocContent
  def self.sync(path_index : String, source : String, updated_at : Time = Time.utc) : Doc
    if doc = DocQuery.new.path_index(path_index).first?
      sync(
        doc,
        source,
        updated_at
      )
    else
      SaveDoc.create!(
        path_index: path_index,
        content: source,
        content_digest: Digest::MD5.hexdigest(source),
        content_updated_at: updated_at
      )
    end
  rescue error : PQ::PQError
    raise error unless error.field_message(:constraint) == "docs_path_index_index"

    sync(
      DocQuery.new.path_index(path_index).first,
      source,
      updated_at
    )
  end

  def self.sync(doc : Doc, source : String, updated_at : Time = Time.utc) : Doc
    digest = Digest::MD5.hexdigest(source)
    return doc if doc.content_digest == digest && doc.content == source

    SaveDoc.update!(
      doc,
      content: source,
      content_digest: digest,
      content_updated_at: doc.content_digest == digest ? doc.content_updated_at : updated_at
    )
  end
end
