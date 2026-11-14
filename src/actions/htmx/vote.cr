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
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
        return head 409 if reason.withdrawn?
        return head 400 if reason.invalid_target? || reason.invalid_vote_type?
      end

      return head 500 if result.nil?

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
