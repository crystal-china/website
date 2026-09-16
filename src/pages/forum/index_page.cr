class Forum::IndexPage < MainLayout
  needs topics : Array(Topic)

  def page_title
    "论坛"
  end

  def content
    section class: "#{page_container_classes} py-10" do
      header class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
        div do
          h1 "论坛", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "讨论 Crystal 语言及其生态。", class: "mt-2 text-sm text-gray-600"
        end

        link "发布主题", to: Forum::New, class: "form-submit" if current_user
      end

      if topics.empty?
        para "还没有主题。", class: "rounded-2xl border border-gray-200 bg-white px-6 py-10 text-center text-gray-500"
      else
        div class: "divide-y divide-gray-200 overflow-hidden rounded-2xl border border-gray-200 bg-white" do
          topics.each do |topic|
            article class: "px-6 py-5 hover:bg-gray-50" do
              h2 class: "text-lg font-semibold" do
                link topic.title, to: Forum::Show.with(id: topic.id), class: "text-[#145591] no-underline hover:underline"
              end

              para class: "mt-2 text-xs text-gray-500" do
                text "#{topic.user.name} 发布于 #{topic.created_at.to_s("%Y-%m-%d %H:%M")}"
              end
            end
          end
        end
      end
    end
  end
end
