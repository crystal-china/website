require "../src/app"
require "../tasks/synchronizations/user_to_reply"

def update_users_last_active_at
  COUNTER_MUTEX.synchronize do
    user_ids = ONLINE_USER_COUNTER.keys

    user_ids.each do |user_id|
      user = UserQuery.find(user_id)
      if (value = ONLINE_USER_COUNTER.read(user_id))
        User::SaveOperation.update!(user, last_active_at: Time.unix(value))
      end
    end
  end
end

def save_view_count
  PageHelpers::PAGINATION_URLS.each do |path|
    count = VIEW_COUNT_CACHE.keys.select { |key| key.ends_with?(path) }.size
    doc = DocQuery.new.path_index(path).first?
    SaveDoc.update!(doc, view_count: doc.view_count + count) if doc
  end
end

CronScheduler.define do
  at("*/5 * * * *") { update_users_last_active_at }
  at("*/2 * * * *") { DB::Synchronizations::UserToReply.new.call }
  # 因为 scheduler 表格会在第 59 分的时候做一个判断，让前一个 hour 变暗，
  # 因此，每个小时整点的时候，必须让 cache 无效
  at("00 * * * * ") { MARKDOWN_CACHE.clear }
  at("*/30 * * * *") { save_view_count }
end
