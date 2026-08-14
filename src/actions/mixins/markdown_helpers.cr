require "../../../tasks/db/seed/hourly_availability"

module MarkdownHelpers
  def markdown_path
    name = current_path.sub(%r{/docs/}, "markdowns/")

    "#{name}.md"
  end

  def content
    content = File.read(markdown_path)

    regex = /TableScheduler20250703 year: (\d+), month: (\d+)/

    if content.match(regex)
      year = $1.to_i
      month = $2.to_i

      Db::Seed::HourlyAvailabilityTask.run(year, month) if HourlyAvailabilityQuery.new.date("#{year}-#{month}-01").none?

      content = content.sub(
        regex,
        TableScheduler.new(year: year, month: month, current_user: current_user).render_to_string
      )
    end

    div class: "prose" do
      raw(MARKDOWN_CACHE.fetch(markdown_path) { markdown content })
    end
  end
end
