class SaveReply < Reply::SaveOperation
  permit_columns user_id, doc_id, reply_id, content
  before_save validate_doc_id_reply_id

  before_save do
    validate_required user_id, content

    if !id.value # 新建的时候
      doc_id.value.try do |doc_id|
        doc = DocQuery.find(doc_id)

        preferences.value = Reply::Preferences.from_json(
          {
            path_for_doc: doc.path_index,
          }.to_json
        )
      end

      reply_id.value.try do |reply_id|
        parent_reply = ReplyQuery.find(reply_id)
        #  - 如果父 reply 已经知道它属于哪个根 reply, 用父 reply 的 root_reply_id
        #    即：至少是第三极评论，第一级 doc，第二级 root reply, 第三极才是父 reply

        # -  如果父 reply 没有 root_reply_id, 说明父 reply 自己就是根评论, 因此就使用它的 id
        #    此时父 reply 就是上面的第二级 root reply
        thread_root_id = parent_reply.root_reply_id || parent_reply.id
        root_reply_id.value = thread_root_id

        preferences.value = Reply::Preferences.from_json(
          {
            path_for_doc: nil,
          }.to_json
        )
      end

      vote_counts.value = Reply::VoteCounts.from_json(
        {
          👍:  0,
          👎:  0,
          😄:  0,
          ❤️: 0,
          🎉:  0,
          😕:  0,
          👀️: 0,
        }.to_json
      )
    end
  end

  private def validate_doc_id_reply_id
    if doc_id.value.blank? == reply_id.value.blank?
      add_error :doc_id_or_reply_id, "必须且只能有一个存在"
    end
  end
end
