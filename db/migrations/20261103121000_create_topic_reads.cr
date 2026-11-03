class CreateTopicReads::V20261103121000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(TopicRead) do
      primary_key id : Int64
      add_belongs_to topic : Topic, on_delete: :cascade, index: false
      add_belongs_to user : User, on_delete: :cascade
      # 0 表示已经读过尚无回复的主题；这是阅读位置，不是可删除评论的外键。
      add last_read_reply_id : Int64, default: 0
      add last_read_at : Time
      add_timestamps
    end

    # 每人每主题只有一个阅读位置；也支持按主题统计独立读者。
    create_index table_for(TopicRead), [:topic_id, :user_id], unique: true
  end

  def rollback : Nil
    drop table_for(TopicRead)
  end
end
