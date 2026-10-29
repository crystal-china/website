Spec.before_each do
  AppDatabase.truncate
  Space::SaveOperation.create!(name: "Crystal 中文社区", slug: "default")
end
