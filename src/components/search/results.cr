class Search::Results < BaseComponent
  needs matches : Array(NamedTuple(title: String, url: String, snippet: String))
  needs query : String
  needs too_short : Bool = false

  def render
    if query.empty?
      para "输入关键词开始搜索。", class: "m-0 px-4 py-6 text-center text-sm text-gray-500"
    elsif too_short?
      para "关键词太短，请继续输入。", class: "m-0 px-4 py-6 text-center text-sm text-gray-500"
    elsif matches.empty?
      para "没有找到匹配的内容。", class: "m-0 px-4 py-6 text-center text-sm text-gray-500"
    else
      ul class: "m-0 list-none divide-y divide-gray-200 p-0" do
        matches.each do |match|
          mount Search::Result,
            title: match[:title],
            url: match[:url],
            snippet: match[:snippet]
        end
      end
    end
  end
end
