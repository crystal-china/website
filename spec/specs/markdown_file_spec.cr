require "../spec_helper"

describe MarkdownFile do
  it "only resolves existing Markdown files inside the markdowns directory" do
    MarkdownFile.resolve("index").should eq("public/markdowns/index.md")
    MarkdownFile.resolve("missing").should be_nil
    MarkdownFile.resolve("../README").should be_nil
    MarkdownFile.resolve("/etc/passwd").should be_nil
  end
end
