require "xml"

class Forum::Feed < BrowserAction
  include Auth::AllowGuests
  include MarkdownFormatter
  include PageHelpers

  accepted_formats [:rss], default: :rss

  get "/forum/feed.xml" do
    topics = TopicQuery.new.created_at.desc_order.limit(20).results

    body = XML.build(encoding: "UTF-8") do |xml|
      xml.element("rss", "xmlns:atom": "http://www.w3.org/2005/Atom", version: "2.0") do
        xml.element("channel") do
          xml.element("title") { xml.text "Crystal China 论坛" }
          xml.element("description") { xml.text "Crystal 语言及其生态的中文讨论" }
          xml.element("link") { xml.text Forum::Index.url }
          xml.element("atom", "link", nil, rel: "self", href: Forum::Feed.url)

          if (latest_topic = topics.first?)
            xml.element("lastBuildDate") { xml.text latest_topic.created_at.to_rfc2822 }
          end

          topics.each do |topic|
            url = Forum::Show.with(id: topic.id).url

            xml.element("item") do
              xml.element("guid", "isPermaLink": true) { xml.text url }
              xml.element("pubDate") { xml.text topic.created_at.to_rfc2822 }
              xml.element("title") { xml.text topic.title }
              xml.element("link") { xml.text url }
              xml.element("description") { xml.cdata user_markdown(topic.content) }
            end
          end
        end
      end
    end

    xml body, content_type: "application/rss+xml"
  end
end
