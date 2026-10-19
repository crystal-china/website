class Db::CleanMissingDocs < LuckyTask::Task
  summary "Audit docs without Markdown files; delete empty ones with --apply"
  switch apply, "Delete docs with no comments or votes"

  def call : Nil
    unless File.file?("public/markdowns/navigation.yml") && Dir["public/markdowns/**/*.md"].present?
      raise "Markdown directory is incomplete; refusing to inspect docs"
    end

    candidates = [] of Int64
    blocked = false

    DocQuery.new.each do |doc|
      path = doc.path_index
      next if path.starts_with?("/docs/") && MarkdownFile.resolve(path.sub(%r{\A/docs/}, ""))

      thread = CommentThreadQuery.new.doc_id(doc.id).first?
      comments = thread ? CommentQuery.new.comment_thread_id(thread.id).select_count : 0
      votes = VoteQuery.new.doc_id(doc.id).select_count
      floor_counter = thread.try(&.floor_counter) || 0

      puts "#{path}: thread=#{thread.try(&.id) || "none"}, comments=#{comments}, doc_votes=#{votes}, floor_counter=#{floor_counter}"

      if comments > 0 || votes > 0 || floor_counter > 0
        blocked = true
      else
        candidates << doc.id
      end
    end

    puts "#{candidates.size} empty docs can be deleted"
    return unless apply?

    raise "Some docs have related data; nothing was deleted" if blocked

    AppDatabase.transaction do
      candidates.each do |id|
        doc = DocQuery.new.id(id).for_update.first
        thread = CommentThreadQuery.new.doc_id(id).for_update.first?
        changed = "#{doc.path_index} changed during cleanup; nothing was deleted"

        if thread
          raise changed if thread.floor_counter > 0
          raise changed if CommentQuery.new.comment_thread_id(thread.id).select_count > 0
        end
        raise changed if VoteQuery.new.doc_id(id).select_count > 0
        raise changed if doc.path_index.starts_with?("/docs/") && MarkdownFile.resolve(doc.path_index.sub(%r{\A/docs/}, ""))

        DocQuery.new.id(id).delete
      end
    end

    puts "Deleted #{candidates.size} docs"
  end
end
