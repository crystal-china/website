class Db::Fix::Usernames < LuckyTask::Task
  summary "Remove whitespace from existing usernames, preserving uniqueness"

  def call
    # PostgreSQL 不支持 \p{Z}，显式包含 Unicode 分隔字符，避免漏掉全角空格等。
    query = UserQuery.new
      .where("name ~ ?", "[[:space:]\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]")
      .id.asc_order
      .limit(200)

    last_id = 0_i64

    loop do
      users = query.id.gt(last_id).results

      break if users.empty?

      # 修复后的记录会退出筛选结果；按 ID 前进，不使用 OFFSET 翻页。
      last_id = users.last.id

      users.each do |user|
        name = user.name.gsub(/[\s\p{Z}]+/, "")

        next if name == user.name

        name = "User#{user.id}" if name.empty?

        while UserQuery.new.name(name).id.not.eq(user.id).any?
          name += "_#{user.id}"
        end

        UpdateUser.update!(user, name: name)

        puts "#{user.id}: #{user.name} -> #{name}"
      end
    end
  end
end
