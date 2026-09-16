class Forum::New < BrowserAction
  get "/forum/new" do
    html Forum::NewPage, operation: SaveTopic.new
  end
end
