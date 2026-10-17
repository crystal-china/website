class UserAuditQuery < UserAudit::BaseQuery
  def latest_password_change_at : Time?
    kind.in([UserAudit::Kind::PasswordChanged, UserAudit::Kind::PasswordRemoved]).id.desc_order.first?.try(&.created_at)
  end
end
