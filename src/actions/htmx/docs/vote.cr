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
    votes = {} of String => Int32
    user_voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      reply = ReplyQuery.new.id(reply_id).for_update.first
      votes = Hash(String, Int32).from_json(reply.votes.to_json)

      AppDatabase.rollback unless votes.has_key?(vote_type)

      vote = VoteQuery.new
        .user_id(current_user.id)
        .reply_id(reply.id)
        .vote_type(vote_type)
        .first?

      if vote
        DeleteVote.delete!(vote)
        votes[vote_type] -= 1
      else
        SaveVote.create!(user_id: current_user.id, reply_id: reply.id, vote_type: vote_type)
        votes[vote_type] += 1
      end

      UpdateReplyVotes.update!(reply, votes: ::Reply::Votes.from_json(votes.to_json))
      user_voted_types = VoteQuery.new.user_id(current_user.id).reply_id(reply.id).map(&.vote_type)
    end

    return head 400 unless transaction_committed

    component(
      Shared::VoteButton,
      votes: votes,
      reply_id: reply_id,
      current_user: current_user,
      voted_types: user_voted_types
    )
  end

  private def toggle_doc_vote(doc_id : Int64, vote_type : String)
    votes = {} of String => Int32
    user_voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      doc = DocQuery.new.id(doc_id).for_update.first
      votes = Hash(String, Int32).from_json(doc.votes.to_json)

      AppDatabase.rollback unless votes.has_key?(vote_type)

      vote = VoteQuery.new
        .user_id(current_user.id)
        .doc_id(doc.id)
        .vote_type(vote_type)
        .first?

      if vote
        DeleteVote.delete!(vote)
        votes[vote_type] -= 1
      else
        SaveVote.create!(user_id: current_user.id, doc_id: doc.id, vote_type: vote_type)
        votes[vote_type] += 1
      end

      UpdateDocVotes.update!(doc, votes: ::Doc::Votes.from_json(votes.to_json))
      user_voted_types = VoteQuery.new.user_id(current_user.id).doc_id(doc.id).map(&.vote_type)
    end

    return head 400 unless transaction_committed

    component(
      Shared::VoteButton,
      votes: votes,
      doc_id: doc_id,
      current_user: current_user,
      voted_types: user_voted_types
    )
  end
end
