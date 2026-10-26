require "spec"
require "../../src/utils/sql_like"

describe SqlLike do
  it "escapes backslashes and LIKE wildcards without escaping replacements again" do
    SqlLike.escape("a\\b%_").should eq("a\\\\b\\%\\_")
  end

  it "preserves ordinary text and leaves wildcard placement to the caller" do
    SqlLike.escape("Crystal 中文 O'Reilly").should eq("Crystal 中文 O'Reilly")
    SqlLike.escape("").should eq("")
  end
end
