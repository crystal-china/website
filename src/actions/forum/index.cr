class Forum::Index < BrowserAction
  include Auth::AllowGuests

  get "/forum" do
    topics = TopicQuery.new.id.desc_order.preload_user.results

    html Forum::IndexPage, topics: topics
  end
end
