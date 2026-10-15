class CreateUserAudit::V20250315162146 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(UserAudit) do
      primary_key id : Int64
      add_timestamps

      add sync_state : Int32, index: true, default: 1
      add user_id : Int64
      add changed_column_name : String
      add from : String
      add to : String
    end

    # 为了使用索引的前缀规则（Prefix Rule），即，通过 sync_state 也很快，
    # 这里索引的字段顺序很重要。
    create_index table_for(UserAudit), [:sync_state, :user_id, :changed_column_name]
  end

  def rollback : Nil
    drop table_for(UserAudit)
  end
end
