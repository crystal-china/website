class Forum::Show < ForumAction
  include Auth::AllowGuests

  get "/forum/:id" do
    topic = TopicQuery.new.id(id).preload_user.preload_node.first?

    if topic.nil?
      return html_with_status(
        Errors::ContentUnavailablePage,
        404,
        content_name: r("common.topic").t
      )
    end

    render_topic(topic)
  end
end
