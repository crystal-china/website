class UserAuditQuery < UserAudit::BaseQuery
  def latest_password_change : UserAudit?
    kind.in([UserAudit::Kind::PasswordChanged, UserAudit::Kind::PasswordRemoved]).id.desc_order.first?
  end
end
