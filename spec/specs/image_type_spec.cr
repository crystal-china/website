require "spec"
require "../../src/utils/image_type"

describe ImageType do
  it "recognizes JPEG, PNG, GIF and WebP from their headers" do
    headers = {
      "\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01" => "image/jpeg",
      "\x89PNG\r\n\x1a\n\x00\x00\x00\x0d"    => "image/png",
      "GIF87a\x01\x00\x01\x00\x00\x00"       => "image/gif",
      "GIF89a\x01\x00\x01\x00\x00\x00"       => "image/gif",
      "RIFF\x16\x00\x00\x00WEBP"             => "image/webp",
    }

    headers.each do |header, mime_type|
      ImageType.detect(IO::Memory.new(header)).should eq(mime_type)
    end
  end

  it "recognizes AVIF from a fixed major brand without validating the rest of the box" do
    headers = {
      "\x00\x00\x00\x10ftypavif",
      "\x00\x00\x00\x10ftypavis",
    }

    headers.each do |header|
      ImageType.detect(IO::Memory.new(header)).should eq("image/avif")
    end
  end

  it "recognizes BMP, TIFF and BigTIFF signatures" do
    headers = {
      "BM\x1a\x00\x00\x00\x00\x00\x00\x00\x1a\x00\x00\x00"         => "image/bmp",
      "II\x2a\x00\x08\x00\x00\x00\x00\x00\x00\x00"                 => "image/tiff",
      "MM\x00\x2a\x00\x00\x00\x08\x00\x00\x00\x00"                 => "image/tiff",
      "II\x2b\x00\x08\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00" => "image/tiff",
      "MM\x00\x2b\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10" => "image/tiff",
    }

    headers.each do |header, mime_type|
      ImageType.detect(IO::Memory.new(header)).should eq(mime_type)
    end
  end

  it "recognizes SVG roots with whitespace, an XML declaration or comments" do
    headers = {
      "<svg/>",
      "<svg></svg>",
      "\n\t<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg/>",
      "\uFEFF<?xml version=\"1.0\"?>\n<!-- icon -->\n<!-- another comment -->\n<svg/>",
    }

    headers.each do |header|
      ImageType.detect(IO::Memory.new(header)).should eq("image/svg+xml")
    end
  end

  it "requires SVG to be the root rather than matching arbitrary text or HTML" do
    headers = {
      "plain text mentions <svg/>",
      "<html><body><svg/></body></html>",
      "<!-- <svg/> --> <html/>",
      "<svg-icon/>",
      "<svgx/>",
      "<?xml version=\"1.0\"?><html/>",
      "\xff<svg/>",
      " " * 4096 + "<svg/>",
    }

    headers.each do |header|
      ImageType.detect(IO::Memory.new(header)).should be_nil
    end
  end

  it "leaves compatible-brand-only and extended-length AVIF headers unsupported" do
    headers = {
      "\x00\x00\x00\x18ftypmif1\x00\x00\x00\x00miafavif",
      "\x00\x00\x00\x18ftypmsf1\x00\x00\x00\x00miafavis",
      "\x00\x00\x00\x01ftyp\x00\x00\x00\x00\x00\x00\x00\x18avif\x00\x00\x00\x00",
    }

    headers.each do |header|
      ImageType.detect(IO::Memory.new(header)).should be_nil
    end
  end

  it "rejects empty, short, unrelated and misleading headers" do
    headers = {
      "",
      "\xff\xd8\xff",
      "\x89PNG\r\n\x1a\n",
      "GIF89a",
      "BM",
      "II\x2a\x00",
      "\x00\x00\x00\x10ftypavi",
      "%PDF-1.7 fake.png",
      "RIFF\x16\x00\x00\x00WAVE",
      "not an image: WEBP avif",
      "\x00\x00\x00\x10xxxxavif",
      "\x00\x00\x00\x14ftypheic\x00\x00\x00\x00mif1",
      "\x00\x00\x00\x10ftypmif1avif",
      "\x00\x00\x00\x10ftypmif1\x00\x00\x00\x00avif",
      "\x00\x00\x00\x18ftypmif1\x00\x00\x00\x00xavifxxx",
    }

    headers.each do |header|
      ImageType.detect(IO::Memory.new(header)).should be_nil
    end
  end
end
