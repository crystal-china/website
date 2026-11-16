require "carbon_smtp_adapter"

BaseEmail.configure do |settings|
  if LuckyEnv.production?
    settings.adapter = Carbon::SmtpAdapter.new
  elsif LuckyEnv.development?
    settings.adapter = Carbon::DevAdapter.new(print_emails: true)
  else
    settings.adapter = Carbon::DevAdapter.new
  end
end
