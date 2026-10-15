require "../../../spec/support/factories/**"

# Add seeds here that are *required* for your app to work.
# For example, you might need at least one admin user or you might need at least
# one category for your blog posts for the app to work.
#
# Use `Db::Seed::SampleData` if your only want to add sample data helpful for
# development.
class Db::Seed::RequiredData < LuckyTask::Task
  summary "Add database records required for the app to work"

  def call : Nil
    # Using a Avram::Factory:
    #
    # Use the defaults, but override just the email
    # UserFactory.create &.email("me@example.com")

    # Using a SaveOperation:
    #
    # SaveUser.create!(email: "me@example.com", nickname: "Jane")
    #
    # You likely want to be able to run this file more than once. To do that,
    # only create the record if it doesn't exist yet:
    #
    # unless UserQuery.new.email("me@example.com").first?
    #  SaveUser.create!(email: "me@example.com", nickname: "Jane")
    # end
    [
      {"综合讨论", "general", "Crystal 语言及其生态相关的综合讨论。", "#16a34a", 100},
      {"求助", "help", "使用 Crystal 时遇到的问题与解决方案。", "#db2777", 90},
      {"新闻", "news", "Crystal 语言、社区及生态的最新动态。", "#f59e0b", 80},
      {"项目与工具", "projects", "分享使用 Crystal 构建的项目、库与开发工具。", "#64748b", 70},
      {"学习资源", "learning", "教程、书籍及其他 Crystal 学习资料。", "#9333ea", 60},
      {"招聘", "jobs", "与 Crystal 相关的工作和合作机会。", "#0284c7", 50},
    ].each do |name, slug, summary, color, position|
      next if NodeQuery.new.slug(slug).first?

      SaveNode.create!(
        name: name,
        slug: slug,
        summary: summary,
        color: color,
        position: position
      )
    end

    puts "Done adding required data"
  end
end
