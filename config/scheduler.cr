require "../src/app"
require "../tasks/db/seed/hourly_availability"
require "../tasks/generate_sitemap"

CronScheduler.define do
  at("0 0 1 * *") do
    now = Time.local
    Db::Seed::HourlyAvailabilityTask.run(now.year, now.month)
  end

  at("17 2 * * *") { GenerateSitemapTask.run } if LuckyEnv.production?
  # MemoryStore 读取 keys 时会顺便删除已经过期的浏览记录。
  at("23 3 * * *") { VIEW_COUNT_CACHE.keys }
  at("*/5 * * * *") { ONLINE_PRESENCE.flush }
  # 因为 scheduler 表格会在第 59 分的时候做一个判断，让前一个 hour 变暗，
  # 因此，每个小时整点的时候，必须让 cache 无效
  at("00 * * * * ") { MARKDOWN_CACHE.clear }
end
