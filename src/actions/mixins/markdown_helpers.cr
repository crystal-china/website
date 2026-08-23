require "../../../tasks/db/seed/hourly_availability"

module MarkdownHelpers
  FRONT_MATTER_RE = /\A---[ \t]*\n(?<yaml>.*?)\n---[ \t]*\n?/m

  def markdown_path
    name = current_path.sub(%r{/docs/}, "markdowns/")

    "#{name}.md"
  end

  def markdown_page_title
    markdown_front_matter.try &.["title"]?.try(&.as_s?) || current_path.split("/").last.gsub(/[_-]/, " ").split.map(&.capitalize).join(" ")
  end

  def markdown_page_sub_title
    front_matter = markdown_front_matter

    front_matter.try &.["sub_title"]?.try(&.as_s?) || front_matter.try &.["subtitle"]?.try(&.as_s?)
  end

  def content
    content = markdown_body

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

  private def markdown_front_matter
    source = File.read(markdown_path)

    source.match(FRONT_MATTER_RE).try do |match|
      YAML.parse(match["yaml"])
    end
  end

  private def markdown_body
    source = File.read(markdown_path)

    source.match(FRONT_MATTER_RE).try do |match|
      return source.byte_slice(match[0].bytesize, source.bytesize - match[0].bytesize)
    end

    source
  end
end
