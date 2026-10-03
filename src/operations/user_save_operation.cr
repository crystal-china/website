class User::SaveOperation
  private def validate_username
    validate_required name
    if name.value.try(&.matches?(/[\s\p{Z}]/))
      name.add_error "不能包含空格或其他空白字符"
    end
  end
end
