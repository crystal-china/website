class Db::Fix::LoginNames < LuckyTask::Task
  summary "Repair legacy @mention identities and case-insensitive conflicts without changing display names"

  def call
    query = UserQuery.new.id.asc_order.limit(200)
    last_id = 0_i64

    loop do
      users = query.id.gt(last_id).results

      break if users.empty?

      last_id = users.last.id

      users.each do |user|
        # Keep the lowest-ID account's spelling when old names differ only by case.
        duplicate = UserQuery.new.login_name_lower(user.login_name_lower).id.lt(user.id).any?

        next if UserLoginName.valid?(user.login_name) && !duplicate

        login_name = UserLoginName.generate(user.login_name)
        UpdateUser.update!(user, login_name: login_name)

        puts "#{user.id}: #{user.login_name} -> #{login_name}"
      end
    end
  end
end
