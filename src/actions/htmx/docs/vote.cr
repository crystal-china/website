class Htmx::Docs::Vote < BrowserAction
  param reply_id : Int64?
  param doc_id : Int64?
  param vote_type : String

  patch "/htmx/docs/vote" do
    return head 401 if current_user.nil?
    return head 400 if reply_id.nil? && doc_id.nil?
    return head 400 if reply_id && doc_id

    if reply_id
      toggle_reply_vote(reply_id.not_nil!, vote_type)
    else
      toggle_doc_vote(doc_id.not_nil!, vote_type)
    end
  end

  private def toggle_reply_vote(reply_id : Int64, vote_type : String)
    vote_counts = {} of String => Int32
    user_voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      reply = ReplyQuery.new.id(reply_id).for_update.first
      vote_counts = Hash(String, Int32).from_json(reply.vote_counts.to_json)

      AppDatabase.rollback unless vote_counts.has_key?(vote_type)

      vote = VoteQuery.new
        .user_id(current_user.id)
        .reply_id(reply.id)
        .vote_type(vote_type)
        .first?

      if vote
        DeleteVote.delete!(vote)
        vote_counts[vote_type] -= 1
      else
        SaveVote.create!(user_id: current_user.id, reply_id: reply.id, vote_type: vote_type)
        vote_counts[vote_type] += 1
      end

      UpdateReplyVoteCounts.update!(reply, vote_counts: ::Reply::VoteCounts.from_json(vote_counts.to_json))
      user_voted_types = VoteQuery.new.user_id(current_user.id).reply_id(reply.id).map(&.vote_type)
    end

    return head 400 unless transaction_committed

    component(
      Shared::VoteButton,
      vote_counts: vote_counts,
      reply_id: reply_id,
      current_user: current_user,
      voted_types: user_voted_types
    )
  end

  private def toggle_doc_vote(doc_id : Int64, vote_type : String)
    vote_counts = {} of String => Int32
    user_voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      doc = DocQuery.new.id(doc_id).for_update.first
      vote_counts = Hash(String, Int32).from_json(doc.vote_counts.to_json)

      AppDatabase.rollback unless vote_counts.has_key?(vote_type)

      vote = VoteQuery.new
        .user_id(current_user.id)
        .doc_id(doc.id)
        .vote_type(vote_type)
        .first?

      if vote
        DeleteVote.delete!(vote)
        vote_counts[vote_type] -= 1
      else
        SaveVote.create!(user_id: current_user.id, doc_id: doc.id, vote_type: vote_type)
        vote_counts[vote_type] += 1
      end

      UpdateDocVoteCounts.update!(doc, vote_counts: ::Doc::VoteCounts.from_json(vote_counts.to_json))
      user_voted_types = VoteQuery.new.user_id(current_user.id).doc_id(doc.id).map(&.vote_type)
    end

    return head 400 unless transaction_committed

    component(
      Shared::VoteButton,
      vote_counts: vote_counts,
      doc_id: doc_id,
      current_user: current_user,
      voted_types: user_voted_types
    )
  end
end
