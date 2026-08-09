class SaveReply < Reply::SaveOperation
  permit_columns user_id, doc_id, reply_id, content
  before_save validate_doc_id_reply_id

  before_save do
    validate_required user_id, content

    user = UserQuery.find(user_id.value.not_nil!)

    user_name.value = user.name

    user.avatar.try do |avatar|
      user_avatar.value = avatar
    end

    if !id.value # 新建的时候
      doc_id.value.try do |doc_id|
        doc = DocQuery.find(doc_id)
        if (last_reply = ReplyQuery.new.doc_id(doc.id).last?)
          floor = last_reply.preferences.floor + 1
        else
          floor = 1
        end

        preferences.value = Reply::Preferences.from_json(
          {
            path_for_doc: doc.path_index,
            floor:        floor,
          }.to_json
        )
      end

      reply_id.value.try do |reply_id|
        reply = ReplyQuery.find(reply_id)
        #  - 如果父 reply 已经知道它属于哪个根 reply, 用父 reply 的 root_reply_id
        #    即：至少是第三极评论，第一级 doc，第二级 root reply, 第三极才是父 reply

        # -  如果父 reply 没有 root_reply_id, 说明父 reply 自己就是根评论, 因此就使用它的 id
        #    此时父 reply 就是上面的第二级 root reply
        root_reply_id.value = reply.root_reply_id || reply.id

        # 针对 reply 的回复，也总是继承所属文档的 doc_id。
        if doc_id.value.nil? && (parent_doc_id = reply.doc_id)
          doc_id.value = parent_doc_id
        end

        if (last_reply = ReplyQuery.new.reply_id(reply.id).last?)
          floor = last_reply.preferences.floor + 1
        else
          floor = 1
        end

        preferences.value = Reply::Preferences.from_json(
          {
            path_for_doc: nil,
            floor:        floor,
          }.to_json
        )
      end

      votes.value = Reply::Votes.from_json(
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
    if doc_id.value.blank? && reply_id.value.blank?
      add_error :doc_id_or_reply_id, "必须至少一个存在"
    end
  end
end
