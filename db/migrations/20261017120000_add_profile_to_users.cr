class AddProfileToUsers::V20261017120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      # 可选的公开资料；旧用户及未填写资料的新用户统一使用空对象。
      add profile : JSON::Any, default: JSON.parse("{}")
    end
  end

  def rollback : Nil
    alter table_for(User) do
      remove :profile
    end
  end
end
