class Upload < BrowserAction
  post "/upload" do
    source = params.from_multipart.last["source"]

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

    response = HTTP::Client.post(
      url: "http://127.0.0.1:8080/-/upload",
      headers: headers,
      body: reader
    )

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
  rescue Socket::ConnectError | IO::TimeoutError
    json(
      {status: "failed", message: "图片上传服务暂时不可用，请稍后重试"},
      HTTP::Status::SERVICE_UNAVAILABLE
    )
  ensure
    reader.try(&.close)
  end
end
