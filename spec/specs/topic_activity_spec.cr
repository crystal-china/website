require "../spec_helper"

describe "Topic activity" do
  it "tracks visible replies, orders active topics first, and rebuilds safely" do
    author = UserFactory.create
    replier = UserFactory.create
    node = SaveNode.create!(name: "活跃测试", slug: "topic-activity", summary: "测试", color: "#16a34a", position: 0)
    topic = SaveTopic.create!(user_id: author.id, node_id: node.id, title: "旧主题", content: "内容")
    newer_topic = SaveTopic.create!(user_id: author.id, node_id: node.id, title: "新主题", content: "内容")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root_at = newer_topic.created_at + 1.minute
    child_at = root_at + 1.minute
    grandchild_at = child_at + 1.minute
    activity = -> do
      current = TopicQuery.new.with_soft_deleted.id(topic.id).first
      {current.replies_count, current.last_reply_user_id, current.last_active_at}
    end

    activity.call.should eq({0, nil, topic.last_active_at})
    TopicQuery.new.last_active_at.desc_order.id.desc_order.first.id.should eq(newer_topic.id)

    root = SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "根评论", created_at: root_at)
    child = SaveComment.create!(user_id: replier.id, parent_id: root.id, content: "子评论", created_at: child_at)
    grandchild = SaveComment.create!(user_id: author.id, parent_id: child.id, content: "后代评论", created_at: grandchild_at)

    activity.call.should eq({3, author.id, grandchild_at})
    TopicQuery.new.last_active_at.desc_order.id.desc_order.first.id.should eq(topic.id)
    TopicQuery.new.id(topic.id).preload_last_reply_user.first.last_reply_user.not_nil!.id.should eq(author.id)

    UpdateComment.update!(grandchild, content: "编辑不改变活跃时间")
    UpdateTopic.update!(topic, title: "编辑后的主题")
    activity.call.should eq({3, author.id, grandchild_at})

    DeleteComment.delete!(grandchild)
    activity.call.should eq({2, replier.id, child_at})
    CommentQuery.new.only_soft_deleted.id(grandchild.id).first.restore
    activity.call.should eq({3, author.id, grandchild_at})
    DeleteComment.delete!(child)
    activity.call.should eq({2, author.id, grandchild_at})

    DeleteComment.delete!(root)
    activity.call.should eq({0, nil, topic.created_at})
    TopicQuery.new.last_active_at.desc_order.id.desc_order.first.id.should eq(newer_topic.id)
    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    activity.call.should eq({2, author.id, grandchild_at})
    CommentQuery.new.only_soft_deleted.id(child.id).first.restore
    activity.call.should eq({3, author.id, grandchild_at})

    DeleteTopic.delete!(topic)
    AppDatabase.exec "UPDATE topics SET replies_count = 0, last_reply_user_id = NULL WHERE id = $1", topic.id
    2.times { TopicActivity.refresh(thread) }
    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    activity.call.should eq({3, author.id, grandchild_at})

    # 批量查询及物理删除不经过 SaveOperation，需显式重算。
    CommentQuery.new.id(grandchild.id).delete
    TopicActivity.refresh(thread)
    activity.call.should eq({2, replier.id, child_at})

    # 不经过 SaveOperation 的插入也更新统计；最后新增的回复直接更新作者和时间。
    # 创建时间较早也不能让这条刚新增的回复被忽略。
    AppDatabase.exec <<-SQL, root.id
      INSERT INTO comments (comment_thread_id, user_id, content, vote_counts, created_at)
      SELECT comment_thread_id, user_id, '较早的回复', vote_counts, created_at
      FROM comments WHERE id = $1
      SQL
    activity.call.should eq({3, author.id, root_at})
  end
end
