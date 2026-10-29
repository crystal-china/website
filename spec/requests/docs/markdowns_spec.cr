require "../../spec_helper"

describe Docs::Markdowns do
  it "shows the incremented reading count and does not count repeated visits from the same IP" do
    doc = DocContent.sync("/docs/index", File.read("public/markdowns/index.md"))
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true

    {0 => "1 view", 10 => "11 views"}.each do |count, expected|
      VIEW_COUNT_CACHE.clear
      SaveDoc.update!(doc, view_count: count)

      2.times do
        Avram::Events::QueryEvent.logged_events.clear
        response = ApiClient.new.get("/docs/index?locale=en")
        metadata = XML.parse_html(response.body).xpath_node("//p[@class='doc-page-meta-text']").not_nil!
        queries = Avram::Events::QueryEvent.logged_events.map(&.query)

        response.status_code.should eq(200)
        metadata.content.should contain(expected)
        queries.count { |sql| sql.starts_with?("SELECT") && sql.includes?("FROM docs") }.should eq(1)
        DocQuery.find(doc.id).view_count.should eq(count + 1)
      end
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
    VIEW_COUNT_CACHE.clear
  end

  it "returns 404 without creating a Doc for a missing Markdown file" do
    path = "/docs/this_document_does_not_exist"

    ApiClient.new.get(path).status_code.should eq(404)
    DocQuery.new.path_index(path).first?.should be_nil
  end

  it "returns 404 when a Doc exists but its Markdown file is missing" do
    path = "/docs/old_document_without_a_file"
    SaveDoc.create!(path_index: path)

    ApiClient.new.get(path).status_code.should eq(404)
  end

  it "does not create a Doc for an encoded alias of an existing Markdown file" do
    path = "/docs/%69ndex"

    ApiClient.new.get(path).status_code.should eq(404)
    DocQuery.new.path_index(path).first?.should be_nil
  end
end
