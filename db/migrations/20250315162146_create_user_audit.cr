class CreateUserAudit::V20250315162146 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(UserAudit) do
      primary_key id : Int64
      add_timestamps

      # 不关联被记录用户，账号被物理删除后仍保留历史。
      add user_id : Int64
      # 实际操作者可与被记录用户不同；操作者删除后保留事件并清空关联。
      add_belongs_to actor : User?, on_delete: :nullify, index: false
      # UserAudit::Kind 的固定整数值；新增事件不要改变已有编号。
      add kind : Int32
      # 资料变更才填写字段和值；登录、密码事件不保存密码或令牌。
      add changed_column_name : String?
      add from : String?
      add to : String?
      add oauth_provider : String?
    end

    create_index table_for(UserAudit), [:user_id, :id]
  end

  def rollback : Nil
    drop table_for(UserAudit)
  end
end
