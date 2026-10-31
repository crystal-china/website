class Shared::CommentPreview < BaseComponent
  needs content : String
  needs render_body : Proc(Nil)
  needs preview_length : Int32 = 160
  # 普通评论把资料栏放进 summary；回收站不传，保留独立的展开文字。
  needs render_header : Proc(Bool, Nil)? = nil

  def render : Nil
    if content.size <= preview_length
      render_header.try &.call(false)
      render_body.call
    else
      details class: render_header ? "comment-preview comment-preview-with-header" : "comment-preview" do
        summary class: "list-none" do
          render_header.try &.call(true)

          span(
            "#{content[0, preview_length].gsub(/\s+/, " ").strip}...",
            class: "comment-preview-excerpt text-base leading-7 break-words text-gray-800"
          )

          if render_header.nil?
            span r(".expand_content").t, class: "comment-preview-expand-label mt-2 block text-sm font-medium text-sky-700"
          end
        end

        render_body.call
      end
    end
  end
end
