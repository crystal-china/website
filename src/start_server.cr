require "./app"

Habitat.raise_if_missing_settings!

if LuckyEnv.development?
  Avram::Migrator::Runner.new.ensure_migrated!
  Avram::SchemaEnforcer.ensure_correct_column_mappings!
  # elsif LuckyEnv.production?
  # Avram::Migrator::Runner.new.run_pending_migrations
end

app_server = AppServer.new

Signal::INT.trap do
  app_server.close
end

private def running_at_background
  extra_space_for_emoji = 1
  (" " * (running_at_message.size + extra_space_for_emoji)).colorize.on_cyan
end

private def running_at_message
  "   🎉 App running at http://#{Lucky::ServerSettings.host}:#{Lucky::ServerSettings.port}   "
end

private def print_running_at
  STDOUT.puts ""
  STDOUT.puts running_at_background
  STDOUT.puts running_at_message.colorize.on_cyan.black
  STDOUT.puts running_at_background
  STDOUT.puts ""
end

print_running_at if LuckyEnv.development?

app_server.listen
