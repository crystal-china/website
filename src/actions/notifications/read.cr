class Notifications::Read < BrowserAction
  post "/notifications/:id/read" do
    notification = NotificationQuery.new.user_id(current_user.id).id(id).for_display.first
    NotificationQuery.new.user_id(current_user.id).id(id).read_at.is_nil.update(read_at: Time.utc)

    if !notification.target_visible?
      flash.info = "相关内容已删除或暂不可见"

      return redirect Notifications::Index
    end

    if (comment_id = notification.comment_id)
      redirect Comments::Show.with(id: comment_id)
    else
      redirect Forum::Show.with(id: notification.topic_id.not_nil!)
    end
  end
end
