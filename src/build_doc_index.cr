require "./actions/mixins/page_helpers"

str = String.build do |io|
  io << "[input]\n"
  io << %(base_directory = "public/markdowns"\n)
  io << "files = [\n"
  DocNavigation.pages.each do |page|
    markdown = "#{page.path.sub("/docs/", "")}.md"
    io << %(    {path = "#{markdown}", url = "#{page.path}", title = "#{page.title}"},\n)
  end
  io << "]"
end

Dir.mkdir_p("tmp")
File.write("tmp/index.toml", str)

abort "Failed to build document search index" unless system("bin/stork build --input tmp/index.toml --output public/markdowns/search-index.st")
