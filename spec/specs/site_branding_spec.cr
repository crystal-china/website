require "../spec_helper"

describe "Site branding" do
  it "uses the Crystal China image and contact email by default" do
    response = ApiClient.new.get("/")
    document = XML.parse_html(response.body)
    brand = document.xpath_node("//header[@class='site-navbar']/div/a[@href='/']").not_nil!
    logo = brand.xpath_node("./img").not_nil!
    email = document.xpath_node("//footer//address/a").not_nil!

    response.status_code.should eq(200)
    logo["src"].should eq(Lucky::AssetHelpers.asset("svgs/crystal-china.svg"))
    logo["width"].should eq("270")
    logo["height"].should eq("33")
    logo["class"].should contain("object-contain")
    logo["class"].should contain("h-[26px] w-[210px]")
    logo["class"].should contain("sm:h-[33px] sm:w-[270px]")
    brand.xpath_node("./span").should be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should_not be_nil
    email.content.should eq("admin@crystal-china.org")
    email["href"].should eq("mailto:admin@crystal-china.org")
    document.xpath_nodes("//footer/nav/a | //footer//nav/a").map { |link| link["href"] }.should eq([
      "https://github.com/crystal-china",
      "https://x.com/crystalchinaorg",
      "https://crystal-lang.org/",
    ])
  end

  it "overrides the source code link and keeps it hidden after explicit clearing" do
    space = UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      source_url: "https://example.com/source"
    )
    document = XML.parse_html(ApiClient.new.get("/").body)

    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should_not be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should be_nil

    space = UpdateSpaceSettings.update!(space, source_url: " ")
    document = XML.parse_html(ApiClient.new.get("/").body)

    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should be_nil
    space.reload.source_url.should eq("")

    UpdateSpaceSettings.update!(space, source_url: "https://example.com/source")

    document = XML.parse_html(ApiClient.new.get("/").body)

    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should_not be_nil
  end

  it "uses configured images and contact emails without changing the image box" do
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    {"svg", "png", "jpg", "webp"}.each do |extension|
      logo_url = "https://example.com/brand.#{extension}"

      space = UpdateSpaceSettings.update!(space, logo_url: logo_url, contact_email: "hello@example.com")
      response = ApiClient.new.get("/")
      document = XML.parse_html(response.body)
      logo = document.xpath_node("//header[@class='site-navbar']/div/a[@href='/']/img").not_nil!
      email = document.xpath_node("//footer//address/a").not_nil!

      response.status_code.should eq(200)
      logo["src"].should eq(logo_url)
      logo["width"].should eq("270")
      logo["height"].should eq("33")
      logo["class"].should contain("object-contain")
      email.content.should eq("hello@example.com")
      email["href"].should eq("mailto:hello@example.com")
    end
  end

  it "stores ordered footer links as JSONB and hides all icons for an empty array" do
    space = UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      footer_links: [
        Space::FooterLink.new(
          title: "Blog",
          url: "https://example.com/blog",
          icon: "https://example.com/blog.png"
        ),
        Space::FooterLink.new(
          title: "Code",
          url: "https://example.com/code",
          icon: "https://example.com/code.svg"
        ),
      ]
    )
    document = XML.parse_html(ApiClient.new.get("/").body)
    links = document.xpath_nodes("//footer//nav/a").to_a

    space.reload.footer_links.not_nil!.map(&.title).should eq(["Blog", "Code"])
    links.map { |link| link["href"] }.should eq(["https://example.com/blog", "https://example.com/code"])
    links.map { |link| link["title"] }.should eq(["Blog", "Code"])
    links.first.xpath_node("./img").not_nil!["src"].should eq("https://example.com/blog.png")

    space = UpdateSpaceSettings.update!(
      space,
      footer_links: [] of Space::FooterLink
    )

    space.reload.footer_links.not_nil!.should be_empty
    XML.parse_html(ApiClient.new.get("/").body).xpath_nodes("//footer//nav/a").should be_empty
  end

  it "hides the logo, contact email and source link when their values are explicitly cleared" do
    space = UpdateSpaceSettings.update!(
      Space::BaseQuery.find(Space::DEFAULT_ID),
      logo_url: "https://example.com/logo.png",
      contact_email: "hello@example.com",
      source_url: "https://example.com/source"
    )

    UpdateSpaceSettings.update!(
      space,
      logo_url: " ",
      contact_email: " ",
      source_url: " "
    )

    document = XML.parse_html(ApiClient.new.get("/").body)

    space.reload.logo_url.should eq("")
    space.contact_email.should eq("")
    space.source_url.should eq("")
    document.xpath_node("//header[@class='site-navbar']/div/a[@href='/']").should be_nil
    document.xpath_node("//footer//address").should be_nil
    document.xpath_node("//header//nav//a[@href='https://example.com/source']").should be_nil
    document.xpath_node("//header//nav//a[@href='#{Space::DEFAULT_SOURCE_URL}']").should be_nil
  end

  it "resolves bundled image paths using the current asset manifest and leaves external images unchanged" do
    Space.image_url(Space::DEFAULT_LOGO_PATH).should eq(Lucky::AssetHelpers.asset("svgs/crystal-china.svg"))
    Space.image_url(Space::DEFAULT_FOOTER_LINKS.first.icon).should eq(Lucky::AssetHelpers.asset("svgs/github-icon.svg"))
    Space.image_url("https://example.com/logo.svg").should eq("https://example.com/logo.svg")
  end

  it "shares one Space lookup between the navbar and footer within each request" do
    context = time_zone_context
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    Avram::Events::QueryEvent.logged_events.clear

    Navbar.new(current_user: nil).context(context).render_to_string
    Footer.new(current_user: nil).context(context).render_to_string

    queries = Avram::Events::QueryEvent.logged_events.map(&.query)

    queries.count(&.matches?(/\bFROM\s+"?spaces"?\b/i)).should eq(1)
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end
end
