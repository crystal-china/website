module ImageType
  private JPEG_SIGNATURE  = Bytes[0xff, 0xd8, 0xff, read_only: true]
  private PNG_SIGNATURE   = Bytes[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, read_only: true]
  private TIFF_SIGNATURES = {
    "II\x2a\x00".to_slice, "MM\x00\x2a".to_slice,
    "II\x2b\x00".to_slice, "MM\x00\x2b".to_slice,
  }
  private AVIF_BRANDS   = {"avif".to_slice, "avis".to_slice}
  private SVG_SIGNATURE = /\A(?:\x{FEFF})?\s*(?:<\?xml\s.*?\?>\s*)?(?:<!--.*?-->\s*)*<svg(?:\s|\/?>)/m

  # 从 IO 当前位置读取最多 4 KiB 文件头，粗略识别八种图片，返回 MIME 类型。
  # 只识别类型，不验证图片完整性，也不清洗 SVG；未知类型返回 nil。
  def self.detect(io : IO) : String?
    header = Bytes.new(4096)
    bytes_read = io.read_greedy(header)
    header = header[0, bytes_read]

    if header.size >= 12
      return "image/jpeg" if header[0, 3] == JPEG_SIGNATURE
      return "image/png" if header[0, 8] == PNG_SIGNATURE
      return "image/gif" if header[0, 6].in?({"GIF87a".to_slice, "GIF89a".to_slice})
      return "image/webp" if header[0, 4] == "RIFF".to_slice && header[8, 4] == "WEBP".to_slice
      return "image/bmp" if header[0, 2] == "BM".to_slice
      return "image/tiff" if header[0, 4].in?(TIFF_SIGNATURES)

      # AVIF 只检查固定位置的主要品牌 avif / avis。
      return "image/avif" if header[4, 4] == "ftyp".to_slice && header[8, 4].in?(AVIF_BRANDS)
    end

    # SVG 从根标签识别，允许 UTF-8 BOM、XML 声明及前置注释。
    svg_header = String.new(header).scrub

    return "image/svg+xml" if SVG_SIGNATURE.matches?(svg_header)

    nil
  end
end
