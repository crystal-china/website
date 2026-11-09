class Htmx::Vote < BrowserAction
  param comment_id : Int64?
  param doc_id : Int64?
  param vote_type : String

  patch "/htmx/vote" do
    ToggleVote.run(
      comment_id: comment_id,
      doc_id: doc_id,
      user_id: current_user.id,
      vote_type: vote_type
    ) do |operation, result|
      if result.nil?
        return head 404 if operation.rejection_reason.try(&.target_unavailable?)
        return head 409 if operation.rejection_reason.try(&.withdrawn?)

        return head 400
      end

      component(
        Shared::VoteButton,
        vote_counts: result[:vote_counts],
        comment_id: comment_id,
        doc_id: doc_id,
        voted_types: result[:voted_types]
      )
    end
  end
end
