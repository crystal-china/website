class Forum::Create < BrowserAction
  post "/forum" do
    SaveTopic.create(params, user_id: current_user.id) do |operation, topic|
      if topic
        redirect Forum::Show.with(id: topic.id)
      else
        build_failed_flash(operation)
        html Forum::NewPage, operation: operation
      end
    end
  end
end
