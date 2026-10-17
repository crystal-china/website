require "spec"
require "../../src/utils/return_path"

describe ReturnPath do
  it "keeps the path and query while discarding the host" do
    {"/forum?page=3", "https://example.com/forum?page=3", "http://example.com/forum?page=3", "//example.com/forum?page=3"}.each do |source|
      ReturnPath.parse(source).should eq("/forum?page=3")
    end
  end

  it "ignores missing, malformed or unsafe return paths" do
    {nil, "", "forum", "javascript:alert(1)", "ftp://example.com/forum", "https://[", "https://example.com//other.example/forum", "/\\example.com"}.each do |source|
      ReturnPath.parse(source).should be_nil
    end
  end
end
