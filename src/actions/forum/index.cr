class Forum::Index < ForumAction
  include Auth::AllowGuests
  include Lucky::Paginator::BackendHelpers

  param node : String?

  get "/forum" do
    query = TopicQuery.new.id.desc_order.preload_user.preload_node

    if (node_slug = node)
      current_node = NodeQuery.new.slug(node_slug).first?
      query = query.node_id(current_node.id) if current_node
    end

    pages, topics = paginate(
      query,
      per_page: 20
    )
    current_topics = topics.results
    topic_activity = {} of Int64 => NamedTuple(comments_count: Int64, last_commenter: String, last_commented_at: Time)

    unless current_topics.empty?
      # 一次汇总当前页的可见回复；根评论删除后，其子评论也不参与统计。
      sql = <<-SQL
        WITH visible_comments AS MATERIALIZED (
          SELECT threads.topic_id, comments.id, comments.user_id, comments.created_at
          FROM comment_threads AS threads
          JOIN comments ON comments.comment_thread_id = threads.id
          LEFT JOIN comments AS roots ON roots.id = comments.root_id
          WHERE threads.topic_id = ANY($1::bigint[])
            AND comments.soft_deleted_at IS NULL
            AND (comments.root_id IS NULL OR roots.soft_deleted_at IS NULL)
        ), counts AS (
          SELECT topic_id, COUNT(*) AS comments_count
          FROM visible_comments
          GROUP BY topic_id
        ), latest AS (
          SELECT DISTINCT ON (topic_id) topic_id, user_id, created_at
          FROM visible_comments
          ORDER BY topic_id, created_at DESC, id DESC
        )
        SELECT counts.topic_id, counts.comments_count, users.name, latest.created_at
        FROM counts
        JOIN latest ON latest.topic_id = counts.topic_id
        JOIN users ON users.id = latest.user_id
        SQL

      AppDatabase.query_all(sql, current_topics.map(&.id)) do |rs|
        topic_id, comments_count, last_commenter, last_commented_at = rs.read(Int64, Int64, String, Time)
        topic_activity[topic_id] = {
          comments_count:    comments_count,
          last_commenter:    last_commenter,
          last_commented_at: last_commented_at,
        }
      end
    end

    html Forum::IndexPage, topics: current_topics, topic_activity: topic_activity, pages: pages, node: current_node
  end
end
