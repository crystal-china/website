class Forum::Show < ForumAction
  include Auth::AllowGuests

  param following : Bool = false

  get "/forum/:id" do
    topic = TopicQuery.new.id(id).preload_user.preload_node.first?

    if topic.nil?
      return html_with_status(
        Errors::ContentUnavailablePage,
        404,
        content_name: r("common.topic").t
      )
    end

    render_topic(topic, followed_topics: following)
  end
end
