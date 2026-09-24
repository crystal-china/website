module Comments
  alias Pagination = NamedTuple(
    count: Int32 | Int64,
    comments: CommentQuery,
    page: Lucky::Paginator?,
    url: String,
    order_by: String,
  )
end
