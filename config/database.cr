database_name = "crystal_china_#{LuckyEnv.environment}"

AppDatabase.configure do |settings|
  if LuckyEnv.production?
    settings.credentials = Avram::Credentials.parse(ENV["DATABASE_URL"])
  else
    settings.credentials = Avram::Credentials.parse?(ENV["DATABASE_URL"]?) || Avram::Credentials.new(
      database: ENV["DB_NAME"]? || database_name,
      hostname: ENV["DB_HOST"]? || "localhost",
      port: ENV["DB_PORT"]?.try(&.to_i) || 5432,
      # Some common usernames are "postgres", "root", or your system username (run 'whoami')
      username: ENV["DB_USERNAME"]? || "postgres",
      # Some Postgres installations require no password. Use "" if that is the case.
      password: ENV["DB_PASSWORD"]? || "postgres"
    )
  end
  print settings.credentials.url
end

struct MyI18n < Avram::I18nBackend
  def get(key : String | Symbol) : String
    {
      validate_acceptance_of:      "must be accepted",
      validate_at_most_one_filled: "must be blank",
      validate_confirmation_of:    "必须匹配",
      validate_exact_size_of:      "长度必须为 %d 个字符",
      validate_exactly_one_filled: "at least one must be filled",
      validate_format_of:          "is invalid",
      validate_inclusion_of:       "is not included in the list",
      validate_max_size_of:        "must not have more than %d characters",
      validate_min_size_of:        "must have at least %d characters",
      validate_numeric_max:        "must be no more than %s",
      validate_numeric_min:        "must be at least %s",
      validate_numeric_nil:        "数字不可以为空",
      validate_required:           "需要的",
      validate_uniqueness_of:      "已经存在了",
    }[key]
  end
end

Avram.configure do |settings|
  settings.database_to_migrate = AppDatabase

  # In production, allow lazy loading (N+1).
  # In development and test, raise an error if you forget to preload associations
  settings.lazy_load_enabled = LuckyEnv.production?

  # Always parse `Time` values with these specific formats.
  # Used for both database values, and datetime input fields.
  # settings.time_formats << "%F"
  settings.i18n_backend = MyI18n.new
end
