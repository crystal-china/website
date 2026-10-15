# This file may be used for custom Application configurations.
# It will be loaded before other config files.
#
# Read more on configuration:
#   https://luckyframework.org/guides/getting-started/configuration#configuring-your-own-code

# Use this code as an example:
#
# ```
# module Application
#   Habitat.create do
#     setting support_email : String
#     setting lock_with_basic_auth : Bool
#   end
# end
#
# Application.configure do |settings|
#   settings.support_email = "support@myapp.io"
#   settings.lock_with_basic_auth = LuckyEnv.staging?
# end
#
# # In your application, call
# # `Application.settings.support_email` anywhere you need it.
# ```

# 项目的 HTMX 4 使用浏览器 fetch()，重定向遵循以下规则：

# 原请求              返回 302      返回 303
# ━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━  ━━━━━━━━━━
# POST                改用 GET      改用 GET
# ──────────────────  ────────────  ──────────
# PUT/PATCH/DELETE    保留原方法    改用 GET

# 303 确保 PUT/PATCH/DELETE 提交后，跳转页面使用 GET
Lucky::Redirectable.configure do |config|
  config.redirect_status = 303
end

# Cache 默认是开启压缩的。
CACHE_STORE = if LuckyEnv.production?
                Cache::MemoryStore(String)
              else
                Cache::NullStore(String)
              end

CAPTCHA_CACHE        = Cache::MemoryStore(String).new(expires_in: 1.minute)
CAPTCHA_MUTEX        = Mutex.new
MARKDOWN_CACHE       = CACHE_STORE.new(expires_in: 1.day)
LATEST_RELEASE_CACHE = CACHE_STORE.new(expires_in: 1.hour)

# 浏览器每两分钟刷新一次；三分钟没有刷新即视为离线。
ONLINE_USERS          = Cache::MemoryStore(Time).new(expires_in: 3.minutes)
ONLINE_GUESTS         = Cache::MemoryStore(Bool).new(expires_in: 3.minutes)
ONLINE_PRESENCE_MUTEX = Mutex.new

VIEW_COUNT_CACHE = Cache::MemoryStore(Bool).new(expires_in: 30.minutes)
VIEW_COUNT_MUTEX = Mutex.new
