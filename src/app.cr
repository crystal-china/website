module App
  # 全站默认每页条数，当前用于：
  # - 社区主题列表、通知列表。
  # - 个人主页的主题、回复、关注者和关注用户列表。
  # - 回收站列表、同批评论列表、主题预览评论，以及关联评论所在页的定位计算。
  # 修改此值会同步调整这些列表；评论和账户记录使用下方的 SMALL_PER_PAGE。
  DEFAULT_PER_PAGE = 20

  # 较短列表的每页条数，当前用于：
  # - Doc／Topic 主评论区、子回复列表，以及评论通知定位时的页码计算。
  # - 个人和后台的账户记录列表。
  # 修改此值会同步调整上述分页和定位计算。
  SMALL_PER_PAGE = 10

  VERSION = {{
              `shards version "#{__DIR__}"`.chomp.stringify +
              " (rev " +
              `git rev-parse --short HEAD`.chomp.stringify +
              ")" +
              `date '+ %Y-%m-%d %H:%M:%S'`.chomp.stringify
            }}
end

require "./shards"

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
