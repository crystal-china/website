class Db::SyncDocContent < LuckyTask::Task
  summary "Sync public/markdowns/*.md into docs for full-text search"

  def call : Nil
    files = Dir["public/markdowns/**/*.md"].sort

    unless File.file?("public/markdowns/navigation.yml") && files.present?
      raise "Markdown directory is incomplete; refusing to mark documents missing"
    end

    present_paths = Set(String).new

    files.each do |file|
      relative_path = Path[file].relative_to(Path["public/markdowns"]).to_s.rchop(".md")
      path_index = "/docs/#{relative_path}"
      DocContent.sync(path_index, File.read(file))
      present_paths.add(path_index)
    end

    puts "Synced #{files.size} Markdown documents"

    missing_paths = [] of String
    DocQuery.new.each do |doc|
      next if present_paths.includes?(doc.path_index)

      SaveDoc.update!(doc, content: nil) unless doc.content.nil?
      missing_paths << doc.path_index
    end

    unless missing_paths.empty?
      puts "Docs without Markdown source:"
      missing_paths.each { |path| puts "  #{path}" }
    end
  end
end
