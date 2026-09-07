class UpdateComment < Comment::SaveOperation
  permit_columns content

  before_save do
    validate_required content
  end
end
