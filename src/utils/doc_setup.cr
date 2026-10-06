module DocSetup
  FILES = {
    DocNavigation::CONFIG_PATH => <<-YAML,
      - path: /docs/index
        title: Documentation
      YAML
    "public/markdowns/index.md" => <<-MARKDOWN,
      ---
      title: Documentation
      subtitle: Start your documentation here
      ---

      Welcome to your documentation.

      ## Add a page

      Create a Markdown file in `public/markdowns/`, for example `guide.md`.
      It is available at `/docs/guide`.

      Add its path and title to `navigation.yml` to include it in the sidebar and pager.
      MARKDOWN
  }

  def self.create_missing_files : Array(String)
    created_files = [] of String
    Dir.mkdir_p(MarkdownFile::ROOT)

    FILES.each do |path, source|
      next if File.exists?(path) || File.symlink?(path)

      file = File.tempfile("doc-setup", ".tmp", dir: MarkdownFile::ROOT.to_s)

      begin
        file << source
        file.flush
        file.chmod(0o644)
        # Publish the complete file without overwriting a file created by another request.
        File.link(file.path, path)
        created_files << path
      rescue File::AlreadyExistsError
      ensure
        file.close
        file.delete
      end
    end

    created_files
  end
end
