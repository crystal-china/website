class Comments::Show < CommentAction
  get "/comments/:id" do
    comment = CommentQuery.new.id(id).preload_comment_thread(&.preload_doc).first?

    if comment.nil? || !comment_available?(comment)
      return html_with_status Errors::ContentUnavailablePage, 404, content_name: r("common.comment").t
    end

    thread = comment.comment_thread
    path = if (topic_id = thread.topic_id)
             Forum::Show.with(id: topic_id).path
           else
             doc = thread.doc.not_nil!

             if doc.content.nil?
               return html_with_status Errors::ContentUnavailablePage, 404, content_name: r("common.comment").t
             end

             doc.path_index
           end

    redirect to: "#{path}?comment_id=#{comment.id}"
  end
end
