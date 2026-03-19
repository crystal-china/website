require "./actions/mixins/page_helpers"

original_size = PageHelpers::PAGINATION_URLS.size
new_size = PageHelpers::PAGINATION_URLS.uniq.size

if original_size != new_size
  abort "duplicated pages for doc, exit!"
end

system("cd public && git clean -fdxq")

str = String.build do |io|
  io << "[input]\n"
  io << %(base_directory = "markdowns"\n)
  io << "files = [\n"
  PageHelpers::PAGINATION_RELATION_MAPPING.each do |k, v|
    markdown = "#{k.sub("/docs/", "")}.md"
    io << %(    {path = "#{markdown}", url = "#{k}", title = "#{v[:title]}"},\n)
  end
  io << "]"
end

File.write("tmp/index.toml", str)

system("bin/stork build --input tmp/index.toml --output public/assets/docs/index.st")

# 创建一个 yaml 文件, 包含文章的修改日期.

require "yaml"

map = {} of String => Int64

Dir["markdowns/**/*.md"].each do |file|
  date = `git --no-pager log -1 --format=%ct #{file}`.chomp

  map[file] = date.to_i64 if date.presence
end

File.write("public/assets/docs/markdowns_timestamps.yml", map.to_yaml)
