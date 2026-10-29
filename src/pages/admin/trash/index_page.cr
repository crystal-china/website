class Admin::Trash::IndexPage < AdminLayout
  needs kind : String
  needs keyword : String
  needs comments : Array(Comment)
  needs topics : Array(Topic)
  needs pages : Lucky::Paginator
  needs focused_comment : Comment? = nil
  needs comment_ids_with_batch_peers : Set(Int64) = Set(Int64).new

  def page_title : String
    r("common.trash").t
  end

  def admin_content : Nil
    nav class: "mb-5 flex gap-3", "aria-label": r(".categories").t do
      link(
        r("common.comment").t,
        to: Admin::Trash::Index.with(q: keyword.presence),
        class: kind == "comments" ? "form-submit" : "form-secondary"
      )
      link(
        r("common.topic").t,
        to: Admin::Trash::Index.with(kind: "topics", q: keyword.presence),
        class: kind == "topics" ? "form-submit" : "form-secondary"
      )
    end

    form(
      action: Admin::Trash::Index.path,
      method: "get",
      class: "mb-5 flex flex-col gap-3 sm:flex-row sm:items-end"
    ) do
      input type: "hidden", name: "kind", value: kind

      div class: "form-field flex-1" do
        label r(".keyword").t, for: "trash-keyword", class: "form-label"
        input(
          type: "search",
          id: "trash-keyword",
          name: "q",
          value: keyword,
          placeholder: r(".keyword_placeholder").t,
          class: "form-input"
        )
      end

      button r("common.search").t, type: "submit", class: "form-submit"
    end

    mount(
      Admin::Trash::List,
      kind: kind,
      comments: comments,
      topics: topics,
      pages: pages,
      focused_comment: focused_comment,
      comment_ids_with_batch_peers: comment_ids_with_batch_peers
    )
  end
end
