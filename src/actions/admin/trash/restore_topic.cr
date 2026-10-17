class Admin::Trash::RestoreTopic < AdminAction
  post "/admin/trash/topics/:id/restore" do
    AppDatabase.transaction do
      topic = TopicQuery.new.only_soft_deleted.id(id).for_update.first
      topic.restore
    end

    flash.success = r(".topic_restored").t

    redirect Admin::Trash::Index.with(kind: "topics")
  end
end
