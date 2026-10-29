require "../spec_helper"
require "../../tasks/db/seed/required_data"

describe Db::Seed::RequiredData do
  it "seeds an empty database and preserves existing configuration when rerun" do
    AppDatabase.truncate
    Db::Seed::RequiredData.new.call

    space = Space::BaseQuery.find(Space::DEFAULT_ID)
    nodes = NodeQuery.new.id.asc_order.results

    space.slug.should eq("default")
    space.topics_count.should eq(0)
    nodes.map(&.slug).should eq(["general", "help", "news", "projects", "learning", "jobs"])
    nodes.each(&.topics_count.should(eq(0)))
    UserQuery.new.any?.should be_false
    TopicQuery.new.any?.should be_false

    space = Space::SaveOperation.update!(
      space,
      name: "保留的站点名称",
      slug: "local-space"
    )

    node = SaveNode.update!(
      nodes.first,
      name: "保留的节点名称",
      slug: "discussion",
      summary: "保留的节点简介",
      color: "#0284c7",
      position: 17
    )

    NodeQuery.new.id(nodes.last.id).delete

    node_ids = NodeQuery.new.id.asc_order.map(&.id)

    Db::Seed::RequiredData.new.call

    Space::BaseQuery.new.select_count.should eq(1)
    NodeQuery.new.id.asc_order.map(&.id).should eq(node_ids)
    space.reload.name.should eq(space.name)
    space.reload.slug.should eq(space.slug)
    space.reload.updated_at.should eq(space.updated_at)
    node.reload.name.should eq(node.name)
    node.reload.slug.should eq(node.slug)
    node.reload.summary.should eq(node.summary)
    node.reload.color.should eq(node.color)
    node.reload.position.should eq(node.position)
    node.reload.updated_at.should eq(node.updated_at)
  end
end
