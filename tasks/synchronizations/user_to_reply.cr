# 调用方式，DB::Synchronizations::UserToReply.new.call
# 之前用来同步 user 的 name avatar 作为冗余字段到 reply，现在移除了。

# class DB::Synchronizations::UserToReply < LuckyTask::Task
#   summary "sync user name and avatar to user replies"

#   def call
#     user_ids = UserAuditQuery.new
#       .sync_state(UserAudit::SyncStatus::Pending)
#       .distinct_on(&.user_id).map(&.user_id)

#     user_ids.each do |user_id|
#       AppDatabase.transaction do
#         UserAuditQuery.new
#           .sync_state(UserAudit::SyncStatus::Pending)
#           .user_id(user_id)
#           .distinct_on(&.changed_column_name)
#           .map do |e|
#             case e.changed_column_name
#             when "name"
#               ReplyQuery.new.user_id(user_id).update(user_name: e.to)
#             when "avatar"
#               ReplyQuery.new.user_id(user_id).update(user_avatar: e.to)
#             end
#           end

#         UserAuditQuery.new
#           .sync_state(UserAudit::SyncStatus::Pending)
#           .user_id(user_id).update(sync_state: UserAudit::SyncStatus::Handled)
#       end
#     end
#   end
# end
