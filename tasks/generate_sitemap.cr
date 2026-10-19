require "xml"

class GenerateSitemap < LuckyTask::Task
  summary "Generate public/sitemap.xml"

  def call : Nil
    GenerateSitemapTask.run
  end
end

module GenerateSitemapTask
  def self.run : Nil
    host = Lucky::RouteHelper.settings.base_uri.chomp('/')
    docs_by_path = {} of String => Doc
    DocQuery.new.each { |doc| docs_by_path[doc.path_index] = doc }

    sitemap = XML.build(
      indent: "  ",
      version: "1.0",
      encoding: "UTF-8"
    ) do |xml|
      xml.element("urlset", xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        add_url(
          xml,
          host,
          Home::Index.path
        )

        Dir["public/markdowns/**/*.md"].sort.each do |file|
          relative_path = Path[file].relative_to(Path["public/markdowns"]).to_s.sub(/\.md\z/, "")
          path = "/docs/#{relative_path}"
          modified_at = docs_by_path[path]?.try do |doc|
            DocContent.sync(doc, File.read(file)).content_updated_at
          end
          add_url(
            xml,
            host,
            path,
            modified_at
          )
        end

        add_url(
          xml,
          host,
          Forum::Index.path
        )

        NodeQuery.new.sorted.each do |node|
          add_url(
            xml,
            host,
            Forum::Index.with(node: node.slug).path,
            node.updated_at
          )
        end

        TopicQuery.new.id.asc_order.each do |topic|
          add_url(
            xml,
            host,
            Forum::Show.with(id: topic.id).path,
            topic.updated_at
          )
        end
      end
    end

    File.write("public/sitemap.xml", sitemap)
  end

  private def self.add_url(xml : XML::Builder, host : String, path : String, lastmod : Time? = nil) : Nil
    xml.element("url") do
      xml.element("loc") { xml.text "#{host}#{path}" }
      xml.element("lastmod") { xml.text lastmod.to_s("%FT%X%:z") } if lastmod
    end
  end
end
