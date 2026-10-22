require "../spec_helper"

describe Shared::Toggle do
  it "renders plain links with consistent styles and selects the exact URL" do
    options = [{"全部", "/forum?node=help"}, {"仅关注", "/forum?node=help&following=true"}]

    options.each do |_, selected|
      html = Shared::Toggle.new(options: options, selected: selected, current_user: nil).render_to_string
      document = XML.parse_html(html)
      links = document.xpath_nodes("//div[@class='segmented-control']/a")

      links.map(&.content).should eq(options.map(&.[0]))
      links.map(&.["href"]).should eq(options.map(&.[1]))
      links.select(&.["class"].includes?("segmented-option-active")).map(&.["href"]).should eq([selected])
      links.each do |link|
        link["class"].should contain("px-2 py-1 text-xs")
        link["hx-get"]?.should be_nil
        link["hx-target"]?.should be_nil
        link["hx-swap"]?.should be_nil
        link["hx-push-url"]?.should be_nil
      end
    end
  end
end
