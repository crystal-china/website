class Db::Rebuild::ContentHtml < LuckyTask::Task
  summary "Rebuild sanitized Topic and Comment HTML, including soft-deleted records (stop the server first)"

  def call
    rebuild(TopicQuery.new.with_soft_deleted, "topics")
    rebuild(CommentQuery.new.with_soft_deleted, "comments")
  end

  private def rebuild(query, table : String)
    last_id = 0_i64
    count = 0

    loop do
      records = query.id.gt(last_id).id.asc_order.limit(200).results

      break if records.empty?

      records.each do |record|
        html = UserMarkdown.render(record.content)[:html]

        # 只更新 HTML，不走 Operation：不改编辑时间、不发通知、不触发评论计数。
        query.id(record.id).update(content_html: html, updated_at: record.updated_at)
      end

      last_id = records.last.id
      count += records.size
      puts "#{table}: rebuilt #{count} records"
    end
  end
end
