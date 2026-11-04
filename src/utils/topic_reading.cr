module TopicReading
  # 只限制未读列表的近期活跃范围，不按创建日期判断，也不删除历史阅读记录。
  UNREAD_PERIOD = 7.days

  # 找出当前列表这一页中，哪些主题对当前用户仍是未读，用于显示蓝色小圆点。
  def self.unread_ids(*, user_id : Int64, topic_ids : Array(Int64)) : Set(Int64)
    return Set(Int64).new if topic_ids.empty?

    # 现在分两段，是为了只查询 ID，不加载完整主题, 等价于
    # TopicQuery.new.unread_by(user_id).id.in(topic_ids).results.map(&.id).to_set
    query = TopicQuery.new
      .unread_by(user_id)
      .id.in(topic_ids)
      .query.select("topics.id")

    AppDatabase.query_all(
      query.statement,
      args: query.args,
      as: Int64
    ).to_set
  end

  # 记录“某个用户，在某个主题里，已经读到了哪个回复 ID”。
  def self.mark_as_read(
    *,
    user_id : Int64,
    topic_id : Int64,
    last_reply_id : Int64?,
  ) : Nil
    # 一次写入，不先查询记录。旧标签页不能把已读位置退回，也不改关注或通知。
    # last_reply_id 0 有实际含义：表示主题看过了，只是当时没有回复。
    # EXCLUDED 可以理解为：这次准备插入，但因为唯一键冲突而没能插入的那一行数据
    # 它是 pg 在这次冲突更新中提供的“待插入行”的名字
    AppDatabase.exec(
      <<-SQL, topic_id, user_id, last_reply_id || 0_i64, Time.utc
        INSERT INTO topic_reads (topic_id, user_id, last_read_reply_id, last_read_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (topic_id, user_id) DO UPDATE
        SET last_read_reply_id = GREATEST(topic_reads.last_read_reply_id, EXCLUDED.last_read_reply_id),
            last_read_at = GREATEST(topic_reads.last_read_at, EXCLUDED.last_read_at),
            updated_at = EXCLUDED.last_read_at
        SQL
    )
  end
end
