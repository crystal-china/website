require "xml"

class XML::Node
  # XML attributes are smaller than LibXML::Node. Reading the whole struct in
  # Crystal's `@node.value && ...` check can cross into inaccessible memory.
  # Read only the shared name field instead (Crystal 1.21.1 workaround).
  def name : String
    if document?
      "document"
    elsif text?
      "text"
    elsif cdata?
      "#cdata-section"
    elsif fragment?
      "#document-fragment"
    elsif (name = @node.value.name)
      String.new(name)
    else
      ""
    end
  end
end
