class Forum::Show < BrowserAction
  include Auth::AllowGuests

  get "/forum/:id" do
    topic = TopicQuery.new.id(id).preload_user.first
    comment_thread = CommentThreadQuery.new.topic_id(topic.id).first

    html Forum::ShowPage, topic: topic, comment_thread: comment_thread
  end
end
