class Forum::Create < ForumAction
  param content : String = ""

  post "/forum" do
    CreateTopic.create(
      params,
      user_id: current_user.id,
      content: content
    ) do |operation, topic|
      if topic
        render_saved_topic(topic)
      else
        context.response.headers["HX-Push-Url"] = "false"

        build_failed_flash(operation)

        html Forum::NewPage, operation: operation
      end
    end
  end
end
