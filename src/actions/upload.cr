class Upload < BrowserAction
  ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/avif",
  }

  post "/upload" do
    source = params.from_multipart.last["source"]
    return json({status: "failed", message: "文件过大"}, HTTP::Status::PAYLOAD_TOO_LARGE) if File.size(source.path) > 5 * 1024 * 1024

    mime_output = IO::Memory.new
    mime_status = Process.run(
      "file",
      ["--brief", "--mime-type", "--", source.path],
      output: mime_output
    )
    mime_type = mime_output.to_s.strip

    unless mime_status.success? && ALLOWED_IMAGE_TYPES.includes?(mime_type)
      return json(
        {status: "failed", message: "只允许上传 JPEG、PNG、GIF、WebP 或 AVIF 图片"},
        HTTP::Status::UNSUPPORTED_MEDIA_TYPE
      )
    end

    # use IO.pipe instead of IO::Memory to reduce memory usage.
    # https://forum.crystal-lang.org/t/upload-image-failed-use-http-client-but-test-with-postman-work/8171/13

    reader, writer = IO.pipe
    form_data = HTTP::FormData::Builder.new(writer)

    spawn do
      file = File.open(source.path) do |file|
        form_data.file("file", file, HTTP::FormData::FileMetadata.new(filename: source.filename))
        form_data.finish
      end
    ensure
      writer.close
    end

    headers = HTTP::Headers.new
    headers["Content-Type"] = form_data.content_type

    upload_uri = URI.parse("http://127.0.0.1:8080/-/upload")
    response = HTTP::Client.new(upload_uri) do |client|
      client.connect_timeout = 2.seconds
      client.write_timeout = 10.seconds
      client.read_timeout = 15.seconds

      client.post(upload_uri.request_target, headers: headers, body: reader)
    end

    body = JSON.parse(response.body)

    if response.success?
      url = body.dig("directLink").as_s
      ext = body.dig("ext")
      if LuckyEnv.production?
        url = url
          .sub("http://127.0.0.1:8080", "https://upload.crystal-china.org")
          .sub("-/file", "files")
      end

      json({status: "success", image_url: "#{url}#{ext}"}, HTTP::Status::OK)
    else
      json({status: "failed", message: body.dig("error")}, HTTP::Status::BAD_REQUEST)
    end
  rescue JSON::ParseException
    json(
      {status: "failed", message: "图片上传服务返回了无效响应"},
      HTTP::Status::BAD_GATEWAY
    )
  rescue Socket::ConnectError | IO::TimeoutError
    json(
      {status: "failed", message: "图片上传服务暂时不可用，请稍后重试"},
      HTTP::Status::SERVICE_UNAVAILABLE
    )
  ensure
    reader.try(&.close)
  end
end
