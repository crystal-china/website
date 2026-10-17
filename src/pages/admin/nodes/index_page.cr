class Admin::Nodes::IndexPage < AdminLayout
  needs nodes : Array(Node)

  def page_title : String
    r("common.nodes").t
  end

  def admin_content : Nil
    header class: "mb-6 flex flex-wrap items-center justify-between gap-4" do
      div do
        h2 r("common.nodes").t, class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
        para r(".description").t, class: "mt-1.5 mb-0 text-sm text-gray-600"
      end

      link r("common.new_node").t, to: Admin::Nodes::New, class: "form-submit"
    end

    div class: "app-panel overflow-hidden" do
      div class: "overflow-x-auto" do
        table class: "w-full border-collapse text-left text-sm" do
          thead class: "bg-gray-50 text-xs font-semibold tracking-wide text-gray-600 uppercase" do
            tr do
              th r("common.node").t, class: "px-5 py-3"
              th r("fields.slug").t, class: "px-5 py-3"
              th r("fields.summary").t, class: "px-5 py-3"
              th r(".order").t, class: "px-5 py-3 text-right"
              th r(".actions").t, class: "px-5 py-3 text-right"
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
                  link r("common.edit").t, to: Admin::Nodes::Edit.with(id: node.id), class: "form-secondary px-3 py-1.5"
                end
              end
            end
          end
        end
      end
    end
  end
end
