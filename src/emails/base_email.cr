# Learn about sending emails
# https://luckyframework.org/guides/emails/sending-emails-with-carbon
abstract class BaseEmail < Carbon::Email
  include Rosetta::Translatable

  macro inherited
    from default_from
  end

  def default_from : Carbon::Address
    Carbon::Address.new("admin@crystal-china.org")
  end
end
