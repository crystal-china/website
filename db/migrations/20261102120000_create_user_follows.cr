class CreateUserFollows::V20261102120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(UserFollow) do
      primary_key id : Int64
      # followed_user 是被关注者；follower 是点击关注的人。
      add_belongs_to followed_user : User, on_delete: :cascade, index: false
      add_belongs_to follower : User, on_delete: :cascade
      add_timestamps
    end

    # 同一用户只能关注一次，也用于查找某个用户的全部关注者。
    create_index table_for(UserFollow), [:followed_user_id, :follower_id], unique: true
    require_different_values(
      table_name: table_for(UserFollow),
      left_column: "followed_user_id",
      right_column: "follower_id"
    )
  end

  def rollback : Nil
    drop table_for(UserFollow)
  end
end
