class RemoveUserPassword < User::SaveOperation
  attribute actor_id : Int64

  before_save do
    validate_required actor_id

    if (id = actor_id.value) && UserQuery.find(id).admin?
      encrypted_password.value = nil
    else
      actor_id.add_error r("validations.admin_required").t
    end
  end

  after_save do |user|
    if encrypted_password.changed?
      SaveUserAudit.create!(
        user_id: user.id,
        actor_id: actor_id.value,
        kind: :password_removed
      )
    end
  end
end
