class Comments::Show < CommentAction
  get "/comments/:id" do
    comment = CommentQuery.new.id(id).preload_comment_thread(&.preload_doc).first

    return head 404 unless comment_available?(comment)

    thread = comment.comment_thread
    path = if (topic_id = thread.topic_id)
             Forum::Show.with(id: topic_id).path
           else
             thread.doc.not_nil!.path_index
           end

    redirect to: "#{path}?comment_id=#{comment.id}#comment-#{comment.id}"
  end
end
