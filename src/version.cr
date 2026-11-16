module App
  VERSION_JSON = {
    rev:    {{`git rev-parse --short HEAD`.chomp.stringify}},
    build:  {{(flag?(:release) ? "release".id : "non-release".id).stringify}},
    assets: {{read_file("#{__DIR__}/../public/bun-manifest.json").includes?("\"js/app-") ? "production" : "development"}},
  }.to_json
  puts VERSION_JSON

  VERSION = {{`shards version "#{__DIR__}"`.chomp.stringify}} + " (#{VERSION_JSON[1..-2]})"

  # 记录编译时间点，供版本接口按本次请求的时区显示。
  BUILT_AT = Time.unix({{`date '+%s'`.chomp.to_i}})
end
