class Users::Show < BrowserAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param show_followed_users : Bool = false
  param show_followers : Bool = false
  param show_replies : Bool = false

  get "/users/:login_name/profile" do
    user = UserQuery.new.with_login_name(login_name).first

    if show_followed_users
      render_followed_users(user)
    elsif show_followers
      render_followers(user)
    elsif show_replies
      render_replies(user)
    else
      render_topics(user)
    end
  end

  private def render_followed_users(user : User) : Lucky::Response
    query = followed_user_query(user.id).id.desc_order.preload_followed_user
    pages, follows = paginate(query, per_page: 20)
    users = follows.results.map(&.followed_user)

    render_profile(
      user,
      users,
      pages,
      tab: :following,
      viewer_followed_user_ids: viewer_followed_user_ids(users)
    )
  end

  private def render_followers(user : User) : Lucky::Response
    query = user_follower_query(user.id).id.desc_order.preload_follower
    pages, follows = paginate(query, per_page: 20)
    users = follows.results.map(&.follower)

    render_profile(
      user,
      users,
      pages,
      tab: :followers,
      viewer_followed_user_ids: viewer_followed_user_ids(users)
    )
  end

  private def render_replies(user : User) : Lucky::Response
    query = CommentQuery.new
      .user_id(user.id)
      .publicly_visible_topic_comments
      .created_at.desc_order
      .id.desc_order
      .preload_comment_thread(&.preload_topic(&.preload_node))

    pages, comments = paginate(query, per_page: 20)

    render_profile(
      user,
      comments.results,
      pages,
      tab: :replies
    )
  end

  private def render_topics(user : User) : Lucky::Response
    query = TopicQuery.new.user_id(user.id).created_at.desc_order.id.desc_order.preload_node
    pages = Lucky::Paginator.new(
      page: paginator_page,
      per_page: 20,
      item_count: user.topics_count,
      full_path: context.request.resource
    )
    topics = query.limit(pages.per_page).offset(pages.offset)

    render_profile(
      user,
      topics.results,
      pages,
      tab: :topics
    )
  end

  private def viewer_followed_user_ids(users : Array(User)) : Array(Int64)
    me = current_user

    return [] of Int64 if me.nil? || users.empty?

    followed_user_query(me.id)
      .followed_user_id.in(users.map(&.id))
      .map(&.followed_user_id)
  end

  private def render_profile(
    user : User,
    entries : Array(Topic) | Array(Comment) | Array(User),
    pages : Lucky::Paginator,
    *,
    tab : Users::ProfileTab::Kind,
    viewer_followed_user_ids : Array(Int64) = [] of Int64,
  ) : Lucky::Response
    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Users::ProfileTab,
        user: user,
        entries: entries,
        pages: pages,
        tab: tab,
        viewer_followed_user_ids: viewer_followed_user_ids
      )
    end

    followed = false

    if (me = current_user) && me.id != user.id
      followed = my_followed_user_query(user.id).any?
    end

    html(
      Users::ShowPage,
      user: user,
      entries: entries,
      pages: pages,
      tab: tab,
      viewer_followed_user_ids: viewer_followed_user_ids,
      followed: followed
    )
  end
end
