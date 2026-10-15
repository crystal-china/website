class Htmx::Vote < BrowserAction
  param comment_id : Int64?
  param doc_id : Int64?
  param vote_type : String

  patch "/htmx/vote" do
    return head 400 if comment_id.nil? && doc_id.nil?
    return head 400 if comment_id && doc_id

    if comment_id
      toggle_comment_vote(comment_id.not_nil!, vote_type)
    else
      toggle_doc_vote(doc_id.not_nil!, vote_type)
    end
  end

  private def toggle_comment_vote(comment_id : Int64, vote_type : String) : Lucky::Response
    vote_counts = {} of String => Int32
    user_voted_types = [] of String
    status = 400

    transaction_committed = AppDatabase.transaction do
      comment = CommentQuery.new.id(comment_id).for_update.first
      unless CommentThreadQuery.find(comment.comment_thread_id).target_visible?
        status = 404
        AppDatabase.rollback
      end

      if (root_id = comment.root_id)
        if CommentQuery.new.id(root_id).none?
          status = 404
          AppDatabase.rollback
        end
      end

      vote_counts = Hash(String, Int32).from_json(comment.vote_counts.to_json)

      AppDatabase.rollback unless vote_counts.has_key?(vote_type)

      votes = VoteQuery.new
        .user_id(current_user.id)
        .comment_id(comment.id)

      if (vote = votes.vote_type(vote_type).first?)
        DeleteVote.delete!(vote)
        vote_counts[vote_type] -= 1
      else
        remove_opposite_vote(votes, vote_type, vote_counts)
        SaveVote.create!(user_id: current_user.id, comment_id: comment.id, vote_type: vote_type)
        vote_counts[vote_type] += 1
      end

      UpdateCommentVoteCounts.update!(comment, vote_counts: ::Comment::VoteCounts.from_json(vote_counts.to_json))
      user_voted_types = VoteQuery.new.user_id(current_user.id).comment_id(comment.id).map(&.vote_type)
    end

    return head status unless transaction_committed

    component(
      Shared::VoteButton,
      vote_counts: vote_counts,
      comment_id: comment_id,
      current_user: current_user,
      voted_types: user_voted_types
    )
  end

  private def toggle_doc_vote(doc_id : Int64, vote_type : String) : Lucky::Response
    vote_counts = {} of String => Int32
    user_voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      doc = DocQuery.new.id(doc_id).for_update.first
      vote_counts = Hash(String, Int32).from_json(doc.vote_counts.to_json)

      AppDatabase.rollback unless vote_counts.has_key?(vote_type)

      votes = VoteQuery.new
        .user_id(current_user.id)
        .doc_id(doc.id)

      if (vote = votes.vote_type(vote_type).first?)
        DeleteVote.delete!(vote)
        vote_counts[vote_type] -= 1
      else
        remove_opposite_vote(votes, vote_type, vote_counts)
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

  private def remove_opposite_vote(votes : VoteQuery, vote_type : String, vote_counts : Hash(String, Int32)) : Nil
    return unless vote_type.in?("👍", "👎")

    opposite_type = vote_type == "👍" ? "👎" : "👍"

    if (opposite_vote = votes.vote_type(opposite_type).first?)
      DeleteVote.delete!(opposite_vote)
      vote_counts[opposite_type] -= 1
    end
  end
end
