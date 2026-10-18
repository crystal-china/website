require "../spec_helper"

describe "Request time zone" do
  it "loads the browser's encoded time zone" do
    time_zone_context("Asia%2FShanghai").time_zone.name.should eq("Asia/Shanghai")
    time_zone_context("UTC").time_zone.should eq(Time::Location::UTC)
  end

  it "falls back to the server time zone for missing, unavailable or invalid names" do
    time_zone_context.time_zone.should eq(Time::Location.local)

    ["", "Missing%2FTimeZone", "..%2F..%2Fetc%2Fpasswd", "%00"].each do |value|
      time_zone_context(value).time_zone.should eq(Time::Location.local)
    end
  end

  it "resolves once per request without sharing the choice between visitors" do
    context = time_zone_context("Asia%2FShanghai")
    context.time_zone.name.should eq("Asia/Shanghai")

    context.request.cookies["time_zone"] = HTTP::Cookie.new("time_zone", "America%2FLos_Angeles")
    context.time_zone.name.should eq("Asia/Shanghai")
    time_zone_context("America%2FLos_Angeles").time_zone.name.should eq("America/Los_Angeles")
  end

  it "renders dates and hover timestamps on the server in the same visitor time zone" do
    created_at = Time.utc(2026, 10, 18, 1, 30)
    last_active_at = created_at + 1.hour
    user = UserFactory.create &.created_at(created_at).last_active_at(last_active_at)

    {"Asia/Shanghai" => "2026-10-18", "America/Los_Angeles" => "2026-10-17"}.each do |name, date|
      value = URI.encode_path(name)
      cookie = "time_zone=#{value}"
      response = ApiClient.new.headers(Cookie: cookie).get("/users/#{user.login_name}/profile")
      card = Forum::AuthorCard.new(user: user, current_user: nil).context(time_zone_context(value)).render_to_string
      location = Time::Location.load(name)

      response.status_code.should eq(200)

      {response.body => date, card => Rosetta.find("forum.author_card.joined").t(date: date)}.each do |html, joined_label|
        document = XML.parse_html(html)
        joined = document.xpath_node("//time[@datetime='#{created_at.to_rfc3339}']").not_nil!
        activity = document.xpath_node("//time[@datetime='#{last_active_at.to_rfc3339}']").not_nil!

        joined.content.should eq(joined_label)
        joined["title"].should eq(created_at.in(location).to_s("%Y-%m-%d %H:%M:%S %z"))
        activity["title"].should eq(last_active_at.in(location).to_s("%Y-%m-%d %H:%M:%S %z"))
        html.should_not contain("data-local-time")
      end
    end
  end
end
