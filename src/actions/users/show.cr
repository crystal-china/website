class Users::Show < BrowserAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param show_replies : Bool = false

  get "/users/:login_name/profile" do
    user = UserQuery.new.with_login_name(login_name).first

    if show_replies
      query = CommentQuery.new.user_id(user.id).publicly_visible_topic_comments.created_at.desc_order.id.desc_order
      query = query.preload_comment_thread(&.preload_topic(&.preload_node))
      pages, comments = paginate(query, per_page: 20)
      entries = comments.results
    else
      query = TopicQuery.new.user_id(user.id).created_at.desc_order.id.desc_order.preload_node
      pages, topics = paginate(query, per_page: 20)
      entries = topics.results
    end

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Users::Topics,
        user: user,
        entries: entries,
        pages: pages,
        show_replies: show_replies,
      )
    end

    html(
      Users::ShowPage,
      user: user,
      entries: entries,
      pages: pages,
      show_replies: show_replies
    )
  end
end
