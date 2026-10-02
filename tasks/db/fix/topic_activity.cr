class Db::Fix::TopicActivity < LuckyTask::Task
  summary "Rebuild topic reply counts and last activity, including deleted topics (safe to rerun)"

  def call
    AppDatabase.exec "SELECT refresh_topic_activity(id) FROM topics ORDER BY id"

    puts "Topic reply counts and last activity rebuilt"
  end
end
