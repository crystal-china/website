class TopicQuery < Topic::BaseQuery
  include Avram::SoftDelete::Query

  def initialize
    defaults &.only_kept
  end

  def unread_by(user_id : Int64) : self
    #  NOT EXISTS 是 SQL 的布尔条件，用来过滤 Topic 查询结果
    #  找不到符合条件的记录保留，找到至少一条符合条件的记录，就排除。
    # 注意，子查询没有记录时，not exists 也成立，数据也保留，也算未读。
    last_active_at.gte(Time.utc - TopicReading::UNREAD_PERIOD).where(
      <<-SQL, user_id
        NOT EXISTS (
          SELECT 1 FROM topic_reads
          WHERE topic_reads.topic_id = topics.id
            AND topic_reads.user_id = ?
            AND topic_reads.last_read_reply_id >= COALESCE(topics.last_reply_id, 0)
        )
        SQL
    )
  end
end
