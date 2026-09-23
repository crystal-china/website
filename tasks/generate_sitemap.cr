require "xml"

class GenerateSitemap < LuckyTask::Task
  summary "Generate public/sitemap.xml"

  def call
    GenerateSitemapTask.run
  end
end

module GenerateSitemapTask
  def self.run
    host = Lucky::RouteHelper.settings.base_uri.chomp('/')

    sitemap = XML.build(indent: "  ", version: "1.0", encoding: "UTF-8") do |xml|
      xml.element("urlset", xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        add_url(xml, host, Home::Index.path)

        Dir["public/markdowns/**/*.md"].sort.each do |file|
          relative_path = Path[file].relative_to(Path["public/markdowns"]).to_s.sub(/\.md\z/, "")
          add_url(xml, host, "/docs/#{relative_path}", File.info(file).modification_time)
        end

        add_url(xml, host, Forum::Index.path)

        TopicQuery.new.id.asc_order.each do |topic|
          add_url(xml, host, Forum::Show.with(id: topic.id).path, topic.updated_at)
        end
      end
    end

    File.write("public/sitemap.xml", sitemap)
  end

  private def self.add_url(xml : XML::Builder, host : String, path : String, lastmod : Time? = nil)
    xml.element("url") do
      xml.element("loc") { xml.text "#{host}#{path}" }
      xml.element("lastmod") { xml.text lastmod.to_s("%FT%X%:z") } if lastmod
    end
  end
end
