class Forum::New < ForumAction
  get "/forum/new" do
    html Forum::NewPage, operation: CreateTopic.new
  end
end
