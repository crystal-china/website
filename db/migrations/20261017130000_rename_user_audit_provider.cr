class RenameUserAuditProvider::V20261017130000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(UserAudit) do
      rename :provider, :oauth_provider
    end
  end

  def rollback : Nil
    alter table_for(UserAudit) do
      rename :oauth_provider, :provider
    end
  end
end
