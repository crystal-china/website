require "../spec_helper"

describe Shared::Avatar do
  it "shows an uppercase initial without an image for missing or blank avatars" do
    {nil, "", " "}.each do |avatar|
      user = UserFactory.create &.nickname("billy").avatar(avatar)
      html = Shared::Avatar.new(user: user, classes: "h-6 w-6 rounded-md text-xs").render_to_string
      document = XML.parse_html(html)
      fallback = document.xpath_node("//span").not_nil!

      fallback.content.should eq("B")
      fallback["aria-hidden"].should eq("true")
      fallback["class"].split.should contain("h-6")
      fallback["class"].split.should contain("rounded-md")
      document.xpath_node("//img").should be_nil
    end
  end

  it "keeps the Chinese initial behind the image and removes broken images" do
    user = UserFactory.create &.nickname("小明").avatar("https://example.com/avatar.png")
    html = Shared::Avatar.new(user: user, classes: "h-10 w-10 rounded-full text-sm").render_to_string
    document = XML.parse_html(html)
    image = document.xpath_node("//img").not_nil!

    image.parent.not_nil!.content.should eq("小")
    image["src"].should eq(user.avatar)
    image["alt"].should eq("")
    image["onerror"].should eq("this.remove()")
    image["class"].split.should contain("absolute")
    image["class"].split.should contain("object-cover")
  end

  it "uses the login-name initial when the nickname is empty" do
    user = UserFactory.create &.login_name("xiaoming")
    UserQuery.new.id(user.id).update(nickname: "")
    user = UserQuery.find(user.id)
    html = Shared::Avatar.new(user: user, classes: "h-8 w-8 rounded-full text-sm").render_to_string

    XML.parse_html(html).xpath_node("//span").not_nil!.content.should eq("X")
  end

  it "escapes the initial and avatar URL as text and attributes" do
    user = UserFactory.create &.nickname("<script>").avatar(%(https://example.com/image.png?name=" onload="alert(1)))
    html = Shared::Avatar.new(user: user, classes: "h-10 w-10 rounded-full text-sm").render_to_string
    document = XML.parse_html(html)
    image = document.xpath_node("//img").not_nil!

    document.xpath_node("//script").should be_nil
    image.parent.not_nil!.content.should eq("<")
    image["src"].should eq(user.avatar)
    image["onload"]?.should be_nil
  end
end
