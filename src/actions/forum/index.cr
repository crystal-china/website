class Forum::Index < BrowserAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  get "/forum" do
    pages, topics = paginate(
      TopicQuery.new.id.desc_order.preload_user,
      per_page: 20
    )

    html Forum::IndexPage, topics: topics, pages: pages
  end
end
