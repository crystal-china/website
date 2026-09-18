require "../../../tasks/db/seed/hourly_availability"

module MarkdownHelpers
  FRONT_MATTER_RE             = /\A---[ \t]*\n(?<yaml>.*?)\n---[ \t]*\n?/m
  TABLE_SCHEDULER_RE          = /TableScheduler20250703 year: (\d+), month: (\d+)/
  TABLE_SCHEDULER_PLACEHOLDER = %(<div data-table-scheduler></div>)

  def markdown_path : String
    request_path = current_path.sub(%r{\A/docs/}, "")

    MarkdownFile.resolve(request_path).not_nil!
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
    scheduler = content.match(TABLE_SCHEDULER_RE).try do |match|
      {match[1].to_i, match[2].to_i}
    end

    if scheduler
      year, month = scheduler

      Db::Seed::HourlyAvailabilityTask.run(year, month) if HourlyAvailabilityQuery.new.date("#{year}-#{month}-01").none?

      content = content.sub(TABLE_SCHEDULER_RE) { TABLE_SCHEDULER_PLACEHOLDER }
    end

    html = MARKDOWN_CACHE.fetch(markdown_path) { markdown content }

    if scheduler
      year, month = scheduler
      html = html.sub(TABLE_SCHEDULER_PLACEHOLDER) do
        TableScheduler.new(year: year, month: month, current_user: current_user).render_to_string
      end
    end

    div class: "prose" do
      raw html
    end
  end

  private memoize def markdown_front_matter : YAML::Any?
    markdown_source.match(FRONT_MATTER_RE).try do |match|
      YAML.parse(match["yaml"])
    end
  end

  private def markdown_body : String
    source = markdown_source

    source.match(FRONT_MATTER_RE).try do |match|
      return source.byte_slice(match[0].bytesize, source.bytesize - match[0].bytesize)
    end

    source
  end

  private memoize def markdown_source : String
    File.read(markdown_path)
  end
end
