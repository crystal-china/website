class UpdateComment < Comment::SaveOperation
  permit_columns content

  before_save do
    validate_required content
    edited_at.value = Time.utc if content.changed?
  end
end
