class CreateTopicFollows::V20261022120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(TopicFollow) do
      primary_key id : Int64
      add_belongs_to topic : Topic, on_delete: :cascade, index: false
      add_belongs_to follower : User, on_delete: :cascade
      add_timestamps
    end

    # 同一用户只关注一次；同时用于查找主题的全部关注者。
    create_index table_for(TopicFollow), [:topic_id, :follower_id], unique: true
  end

  def rollback : Nil
    drop table_for(TopicFollow)
  end
end
