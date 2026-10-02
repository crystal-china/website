class Db::Fix::TopicActivity < LuckyTask::Task
  summary "Rebuild topic reply counts and last activity, including deleted topics (safe to rerun)"

  def call
    CommentThreadQuery.new.topic_id.is_not_nil.each do |thread|
      ::TopicActivity.refresh(thread)
    end

    puts "Topic reply counts and last activity rebuilt"
  end
end
