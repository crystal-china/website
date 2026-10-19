class AddOnlineSecondsToUsers::V20261019120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      # 心跳确认的累计在线秒数，每五分钟写回；不是登录时长，也不补算历史数据。
      add online_seconds : Int64, default: 0_i64
    end
  end

  def rollback : Nil
    alter table_for(User) do
      remove :online_seconds
    end
  end
end
