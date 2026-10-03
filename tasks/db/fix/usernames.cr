class Db::Fix::Usernames < LuckyTask::Task
  summary "Remove whitespace from existing usernames, preserving uniqueness"

  def call
    UserQuery.new.results.each do |user|
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
