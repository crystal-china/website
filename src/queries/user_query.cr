class UserQuery < User::BaseQuery
  def with_login_name(value : String) : self
    where("login_name_lower = lower(?)", value)
  end

  def with_login_names(values : Array(String)) : self
    return where("FALSE") if values.empty?

    placeholders = Array.new(values.size, "lower(?)").join(", ")

    where("login_name_lower IN (#{placeholders})", args: values)
  end
end
