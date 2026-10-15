require "spec"
require "../../src/utils/xml_node"

{% if flag?(:linux) %}
  require "c/sys/mman"
  require "c/unistd"
{% end %}

describe XML::Node do
  it "reads attribute names and values" do
    document = XML.parse(%(<root name="example" color="blue"/>))
    root = document.first_element_child.not_nil!

    root.attributes.map(&.name).should eq(["name", "color"])
    root["name"].should eq("example")
    root["color"].should eq("blue")
  end

  it "preserves document, element, text, and CDATA names" do
    document = XML.parse("<root>text<![CDATA[data]]></root>")
    root = document.first_element_child.not_nil!

    document.name.should eq("document")
    root.name.should eq("root")
    root.children.map(&.name).should eq(["text", "#cdata-section"])
  end

  {% if flag?(:linux) %}
    it "does not read past an attribute at the end of a memory page" do
      page_size = LibC.sysconf(LibC::SC_PAGESIZE)
      memory = LibC.mmap(nil, (page_size * 2).to_u64, LibC::PROT_READ | LibC::PROT_WRITE,
        LibC::MAP_PRIVATE | LibC::MAP_ANONYMOUS, -1, 0)
      raise "mmap failed" if memory.address == UInt64::MAX

      begin
        # The next page is inaccessible: reading a full Node instead of Attr
        # would cross the boundary and reproduce the production crash.
        raise "mprotect failed" unless LibC.mprotect(memory + page_size, page_size.to_u64, LibC::PROT_NONE).zero?

        document = XML.parse(%(<root name="example"/>))
        original = document.first_element_child.not_nil!.attributes["name"].to_unsafe.as(LibXML::Attr*)
        attribute = (memory + page_size - sizeof(LibXML::Attr)).as(LibXML::Attr*)
        attribute.value = original.value
        node = XML::Node.new(attribute.as(LibXML::Node*), document)

        node.name.should eq("name")
      ensure
        LibC.munmap(memory, (page_size * 2).to_u64)
      end
    end
  {% end %}
end
