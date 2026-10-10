class AddMentionNotificationPreference::V20261010120000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(User) do
      # Existing and new users receive mentions by default. Disabling this
      # affects only future mention notifications, not replies or history.
      add mention_notifications_enabled : Bool, default: true
    end
  end

  def rollback
    alter table_for(User) do
      remove :mention_notifications_enabled
    end
  end
end
