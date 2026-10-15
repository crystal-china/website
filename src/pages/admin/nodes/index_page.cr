class Admin::Nodes::IndexPage < AdminLayout
  needs nodes : Array(Node)

  def page_title : String
    "节点管理"
  end

  def admin_content : Nil
    header class: "mb-6 flex flex-wrap items-center justify-between gap-4" do
      div do
        h2 "节点管理", class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
        para "节点决定社区主题的分类和显示顺序。", class: "mt-1.5 mb-0 text-sm text-gray-600"
      end

      link "新增节点", to: Admin::Nodes::New, class: "form-submit"
    end

    div class: "app-panel overflow-hidden" do
      div class: "overflow-x-auto" do
        table class: "w-full border-collapse text-left text-sm" do
          thead class: "bg-gray-50 text-xs font-semibold tracking-wide text-gray-600 uppercase" do
            tr do
              th "节点", class: "px-5 py-3"
              th "路径标识", class: "px-5 py-3"
              th "简介", class: "px-5 py-3"
              th "排序", class: "px-5 py-3 text-right"
              th "操作", class: "px-5 py-3 text-right"
            end
          end

          tbody class: "divide-y divide-gray-200" do
            nodes.each do |node|
              tr class: "hover:bg-gray-50" do
                td class: "px-5 py-4" do
                  div class: "flex items-center gap-3" do
                    span class: "h-3 w-3 shrink-0 rounded-sm", style: "background-color: #{node.color}"
                    link node.name, to: Forum::Index.with(node: node.slug), class: "font-medium text-[#145591] no-underline hover:underline"
                  end
                end
                td node.slug, class: "px-5 py-4 font-mono text-xs text-gray-600"
                td node.summary, class: "max-w-md px-5 py-4 text-gray-600"
                td node.position.to_s, class: "px-5 py-4 text-right tabular-nums text-gray-700"
                td class: "px-5 py-4 text-right" do
                  link "编辑", to: Admin::Nodes::Edit.with(id: node.id), class: "form-secondary px-3 py-1.5"
                end
              end
            end
          end
        end
      end
    end
  end
end
