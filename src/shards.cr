# Load .env file before any other config or app code
require "lucky_env"
LuckyEnv.load?(".env")

# Require your shards here
require "lucky"
require "avram/lucky"
require "carbon"
require "authentic"
require "jwt"
require "baked_file_system_mounter"
require "tartrazine" # optional dependency for markd to render markdown code block.
require "markd"
require "cron_scheduler"
require "time_in_words"
# require "lucky_cache"
require "cache"
require "simple_captcha"
require "multi_auth"
MultiAuth.config("github", ENV["GITHUB_OAUTH_CLIENT_ID"]? || "", ENV["GITHUB_OAUTH_SECRET"]? || "")
MultiAuth.config("google", ENV["GOOGLE_OAUTH_CLIENT_ID"]? || "", ENV["GOOGLE_OAUTH_SECRET"]? || "")

require "debug"
