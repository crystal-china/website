require "../spec_helper"

describe "User activity display" do
  it "shows localized activity times and full timestamps on profiles and author cards" do
    user = UserFactory.create &.last_active_at(Time.utc - 2.hours)
    last_active_at = user.last_active_at.not_nil!

    {"zh-CN" => "大约两小时前", "en" => "about 2 hours ago"}.each do |locale, expected|
      Rosetta.with_locale(locale) do
        response = ApiClient.new.get("/users/#{user.login_name}/profile?locale=#{locale}")
        card = Forum::AuthorCard.new(user: user, current_user: nil).render_to_string

        response.status_code.should eq(200)

        [response.body, card].each do |html|
          document = XML.parse_html(html)
          time = document.xpath_node("//time").not_nil!

          document.content.should contain(Rosetta.find("common.last_active").t)
          time.content.should eq(expected)
          time["datetime"].should eq(last_active_at.to_rfc3339)
          time["title"].should eq(last_active_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z"))
        end
      end
    end
  end

  it "omits activity times when no activity has been recorded" do
    user = UserFactory.create &.last_active_at(nil)
    response = ApiClient.new.get("/users/#{user.login_name}/profile")
    card = Forum::AuthorCard.new(user: user, current_user: nil).render_to_string

    response.status_code.should eq(200)

    [response.body, card].each do |html|
      XML.parse_html(html).xpath_node("//time").should be_nil
    end
  end
end
