module App
  VERSION = {{
              `shards version "#{__DIR__}"`.chomp.stringify +
              " (rev " +
              `git rev-parse --short HEAD`.chomp.stringify +
              ")" +
              `date '+ %Y-%m-%d %H:%M:%S'`.chomp.stringify
            }}
end

require "./shards"

# 先 mount dist/mix-manifest.json, 再读取它
require "../config/backed_file_system_mounter"

Lucky::AssetHelpers.load_manifest

require "./utils/**"
require "../config/server"
require "./app_database"
require "../config/**"
require "./models/base_model"
require "./models/mixins/**"
require "./models/**"
require "./queries/mixins/**"
require "./queries/**"
require "./operations/mixins/**"
require "./operations/**"
require "./serializers/base_serializer"
require "./serializers/**"
require "./emails/base_email"
require "./emails/**"
require "./actions/mixins/**"
require "./actions/**"
require "./components/base_component"
require "./components/**"
require "./pages/**"
require "../db/migrations/**"
require "./app_server"
