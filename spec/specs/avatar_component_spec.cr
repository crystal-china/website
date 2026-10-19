require "../spec_helper"

describe Shared::Avatar do
  it "shows an uppercase initial for missing or blank avatars" do
    {nil, "", " "}.each do |avatar|
      user = UserFactory.create &.nickname("billy").avatar(avatar)
      html = Shared::Avatar.new(
        user: user,
        classes: "h-6 w-6 rounded-md text-xs"
      ).render_to_string
      document = XML.parse_html(html)
      fallback = document.xpath_node("//span[contains(@class, 'user-avatar')]").not_nil!

      fallback.content.should eq("B")
      fallback["aria-hidden"].should eq("true")
      fallback["class"].split.should contain("h-6")
      fallback["class"].split.should contain("rounded-md")
      document.xpath_node("//img").should be_nil
    end
  end

  it "keeps the Chinese initial behind the image and removes broken images" do
    user = UserFactory.create &.nickname("小明").avatar("https://example.com/avatar.png")
    html = Shared::Avatar.new(
      user: user,
      classes: "h-10 w-10 rounded-full text-sm"
    ).render_to_string
    document = XML.parse_html(html)
    images = document.xpath_nodes("//img")
    image = document.xpath_node("//img[@onerror]").not_nil!

    images.size.should eq(1)
    image.parent.not_nil!.content.should eq("小")
    image["src"].should eq("https://example.com/avatar.png")
    image["alt"].should eq("")
    image["onerror"].should eq("this.remove()")
    image["class"].split.should contain("absolute")
    image["class"].split.should contain("object-cover")
  end

  it "escapes initials and avatar URLs" do
    url = %(https://example.com/image.png?name=" onload="alert(1))
    user = UserFactory.create &.nickname("<script>").avatar(url)
    html = Shared::Avatar.new(
      user: user,
      classes: "h-10 w-10 rounded-full text-sm"
    ).render_to_string
    document = XML.parse_html(html)
    image = document.xpath_node("//img[@onerror]").not_nil!

    document.xpath_node("//script").should be_nil
    image.parent.not_nil!.content.should eq("<")
    image["src"].should eq(url)
    image["onload"]?.should be_nil
  end

  it "keeps the background color tied to the account rather than the nickname" do
    user = UserFactory.create
    other = UserFactory.create
    renamed = UpdateUser.update!(user, nickname: "Another nickname")
    colors = {user, renamed, other}.map do |account|
      html = Shared::Avatar.new(
        user: account,
        classes: "h-10 w-10 rounded-full text-sm"
      ).render_to_string

      XML.parse_html(html).xpath_node("//span").not_nil!["class"].split.find!(&.starts_with?("bg-"))
    end

    colors[0].should eq(colors[1])
    colors[0].should_not eq(colors[2])
  end
end
