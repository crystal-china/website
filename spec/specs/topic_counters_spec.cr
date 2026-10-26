require "../spec_helper"
require "../../tasks/db/fix/topic_counts"

private def counter_topic(user : User, node : Node, *, soft_deleted_at : Time? = nil) : Topic
  CreateTopic.create!(
    user_id: user.id,
    node_id: node.id,
    title: "主题计数测试",
    content: "正文",
    soft_deleted_at: soft_deleted_at
  )
end

private def topic_counter_values(user : User, node : Node) : Tuple(Int32, Int32, Int32)
  {
    Space::BaseQuery.find(Space::DEFAULT_ID).topics_count,
    node.reload.topics_count,
    user.reload.topics_count,
  }
end

private def counter_node(slug : String) : Node
  SaveNode.create!(name: slug, slug: slug, summary: "计数测试", color: "#16a34a", position: 0)
end

describe "Topic counters" do
  it "counts only kept topics across inserts, soft deletion, restoration and physical deletion" do
    user = UserFactory.create
    other = UserFactory.create
    node = counter_node("topic-counts")
    empty_node = counter_node("empty-topic-counts")

    topic_counter_values(user, node).should eq({0, 0, 0})
    kept = counter_topic(user, node)
    deleted = counter_topic(user, node, soft_deleted_at: Time.utc)
    topic_counter_values(user, node).should eq({1, 1, 1})
    topic_counter_values(other, empty_node).should eq({1, 0, 0})
    UpdateTopic.update!(kept, title: "编辑不影响数量")
    topic_counter_values(user, node).should eq({1, 1, 1})
    DeleteTopic.delete!(kept)
    topic_counter_values(user, node).should eq({0, 0, 0})
    TopicQuery.new.with_soft_deleted.id(kept.id).update(soft_deleted_at: Time.utc)
    topic_counter_values(user, node).should eq({0, 0, 0})
    TopicQuery.new.only_soft_deleted.id(kept.id).first.restore
    topic_counter_values(user, node).should eq({1, 1, 1})
    TopicQuery.new.with_soft_deleted.id(deleted.id).delete
    topic_counter_values(user, node).should eq({1, 1, 1})
    TopicQuery.new.id(kept.id).delete
    topic_counter_values(user, node).should eq({0, 0, 0})
    user.reload.updated_at.should eq(user.updated_at)
    node.reload.updated_at.should eq(node.updated_at)
  end

  it "adjusts node counters through UpdateTopic without changing space or author totals" do
    user = UserFactory.create
    first = counter_node("first-counter-node")
    second = counter_node("second-counter-node")
    topic = counter_topic(user, first)
    space = Space::BaseQuery.find(Space::DEFAULT_ID)

    topic.space_id.should eq(space.id)
    topic.reload(&.preload_space).space.id.should eq(space.id)

    topic = UpdateTopic.update!(topic, node_id: second.id)
    topic_counter_values(user, first).should eq({1, 0, 1})
    second.reload.topics_count.should eq(1)
    topic = UpdateTopic.update!(topic, node_id: second.id, title: "同一节点重复保存")
    topic_counter_values(user, second).should eq({1, 1, 1})
    edited_at = topic.edited_at

    topic = UpdateTopic.update!(topic, node_id: first.id)
    topic_counter_values(user, first).should eq({1, 1, 1})
    second.reload.topics_count.should eq(0)

    # 只移动节点不改变内容编辑时间，也不改 Space、作者或节点的编辑时间。
    TopicQuery.find(topic.id).edited_at.should eq(edited_at)
    space.reload.updated_at.should eq(space.updated_at)
    first.reload.updated_at.should eq(first.updated_at)
    second.reload.updated_at.should eq(second.updated_at)
    user.reload.updated_at.should eq(user.updated_at)
  end

  it "does not move node counts when validation fails" do
    user = UserFactory.create
    first = counter_node("failed-source")
    second = counter_node("failed-destination")
    topic = counter_topic(user, first)

    UpdateTopic.update(topic, node_id: second.id, content: "") do |operation, _|
      operation.saved?.should be_false
    end

    topic_counter_values(user, first).should eq({1, 1, 1})
    second.reload.topics_count.should eq(0)
    TopicQuery.find(topic.id).node_id.should eq(first.id)
  end

  it "rolls back counters with topic changes and maintains totals when an author is deleted" do
    user = UserFactory.create
    other = UserFactory.create
    node = counter_node("transaction-counts")
    target = counter_node("rollback-target")
    topic = counter_topic(user, node)
    counter_topic(other, node)

    expect_raises(Exception, "rollback topic counts") do
      AppDatabase.transaction do
        UpdateTopic.update!(topic, node_id: target.id)
        counter_topic(user, target)
        topic_counter_values(user, target).should eq({3, 2, 2})

        raise "rollback topic counts"
      end
    end

    topic_counter_values(user, node).should eq({2, 2, 1})
    target.reload.topics_count.should eq(0)
    UserQuery.new.id(user.id).delete
    topic_counter_values(other, node).should eq({1, 1, 1})
  end

  it "repairs counters after the cascading truncation used by sample data" do
    user = UserFactory.create
    node = counter_node("truncate-counts")
    counter_topic(user, node)
    TopicQuery.truncate(cascade: true)
    Db::Fix::TopicCounts.new.call
    topic_counter_values(user, node).should eq({0, 0, 0})
    counter_topic(user, node)
    topic_counter_values(user, node).should eq({1, 1, 1})
    UserQuery.truncate(cascade: true)
    Db::Fix::TopicCounts.new.call
    Space::BaseQuery.find(Space::DEFAULT_ID).topics_count.should eq(0)
    node.reload.topics_count.should eq(0)

    user = UserFactory.create
    counter_topic(user, node)
    topic_counter_values(user, node).should eq({1, 1, 1})
  end

  it "backfills existing topics and repairs counters without changing timestamps or sending notifications" do
    user = UserFactory.create
    empty_user = UserFactory.create
    node = counter_node("backfill-topic-counts")
    empty_node = counter_node("backfill-empty-node")
    topic = counter_topic(user, node)
    counter_topic(user, node, soft_deleted_at: Time.utc)
    notifications_count = NotificationQuery.new.select_count
    migration = AddTopicCounters::V20261026120000.new
    space = Space::SaveOperation.update!(Space::BaseQuery.find(Space::DEFAULT_ID), name: "保留的空间名称")

    migration.down(quiet: true)
    Space::BaseQuery.find(space.id).topics_count.should eq(1)
    migration.up(quiet: true)
    TopicQuery.new.with_soft_deleted.map(&.space_id).uniq!.should eq([Space::DEFAULT_ID])
    Space::BaseQuery.find(space.id).name.should eq(space.name)
    Space::BaseQuery.find(space.id).updated_at.should eq(space.updated_at)
    topic_counter_values(user, node).should eq({1, 1, 1})
    topic_counter_values(empty_user, empty_node).should eq({1, 0, 0})
    AppDatabase.exec("UPDATE spaces SET topics_count = 99")
    AppDatabase.exec("UPDATE nodes SET topics_count = 99")
    AppDatabase.exec("UPDATE users SET topics_count = 99")
    Db::Fix::TopicCounts.new.call
    Db::Fix::TopicCounts.new.call
    topic_counter_values(user, node).should eq({1, 1, 1})
    topic_counter_values(empty_user, empty_node).should eq({1, 0, 0})
    Space::BaseQuery.new.select_count.should eq(1)
    user.reload.updated_at.should eq(user.updated_at)
    empty_user.reload.updated_at.should eq(empty_user.updated_at)
    node.reload.updated_at.should eq(node.updated_at)
    empty_node.reload.updated_at.should eq(empty_node.updated_at)
    TopicQuery.find(topic.id).updated_at.should eq(topic.updated_at)
    NotificationQuery.new.select_count.should eq(notifications_count)
  ensure
    migration.try(&.up(quiet: true)) if migration.try(&.pending?)
  end

  it "paginates site, node and author topics without COUNT, while preserving followed-topic filtering" do
    user = UserFactory.create
    other = UserFactory.create
    node = counter_node("paginated-topic-counts")
    other_node = counter_node("other-paginated-node")
    topics = Array.new(24) { counter_topic(user, node) }
    DeleteTopic.delete!(topics.last)

    4.times do
      counter_topic(other, other_node)
    end

    # 关注筛选不能直接使用站点/节点数量；同时测试一个已删除的关注主题。
    topics.first(4).each do |topic|
      SaveTopicFollow.create!(topic_id: topic.id, follower_id: other.id)
    end

    SaveTopicFollow.create!(topic_id: topics.last.id, follower_id: other.id)
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    client = ApiClient.new
    paths = {
      "/forum?page=2"                            => {"forum-topics", 7},
      "/forum?node=#{node.slug}&page=2"          => {"forum-topics", 3},
      "/forum?node=missing-node&page=2"          => {"forum-topics", 7},
      "/users/#{user.login_name}/profile?page=2" => {"user-topics", 3},
    }

    {false, true}.each do |partial|
      client.headers("HX-Request-Type": partial ? "partial" : "full")

      paths.each do |path, (list_id, expected_size)|
        Avram::Events::QueryEvent.logged_events.clear
        response = client.get(path)
        queries = Avram::Events::QueryEvent.logged_events.map(&.query)

        response.status_code.should eq(200)
        XML.parse_html(response.body).xpath_nodes("//*[@id='#{list_id}']//article").size.should eq(expected_size)
        queries.any?(&.matches?(/\bCOUNT\s*\(/i)).should be_false
      end
    end

    {"following=true", "following=true&node=#{node.slug}"}.each do |filter|
      Avram::Events::QueryEvent.logged_events.clear
      response = client.get("/forum?#{filter}&backdoor_user_id=#{other.id}")
      queries = Avram::Events::QueryEvent.logged_events.map(&.query)

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_nodes("//*[@id='forum-topics']//article").size.should eq(4)
      queries.any?(&.matches?(/\bCOUNT\s*\(/i)).should be_true
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end
end
