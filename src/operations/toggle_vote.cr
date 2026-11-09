class ToggleVote < Avram::Operation
  needs user_id : Int64
  needs vote_type : String
  needs comment_id : Int64? = nil
  needs doc_id : Int64? = nil

  enum RejectionReason
    InvalidTarget
    TargetUnavailable
    Withdrawn
    InvalidVoteType
  end

  getter rejection_reason : RejectionReason?

  # 切换用户对评论或文档的投票，同时更新投票记录、互斥的赞踩和目标计数。
  def run : NamedTuple(vote_counts: Hash(String, Int32), voted_types: Array(String))?
    if (comment_id && doc_id) || (comment_id.nil? && doc_id.nil?)
      @rejection_reason = RejectionReason::InvalidTarget

      return nil
    end

    if (id = comment_id)
      toggle_comment_vote(id)
    else
      toggle_doc_vote(doc_id.not_nil!)
    end
  end

  private def toggle_comment_vote(comment_id : Int64) : NamedTuple(vote_counts: Hash(String, Int32), voted_types: Array(String))?
    vote_counts = {} of String => Int32
    voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      comment = CommentQuery.new.id(comment_id).for_update.first

      unless CommentQuery.new.id(comment.id).publicly_visible_comments.any?
        @rejection_reason = RejectionReason::TargetUnavailable

        AppDatabase.rollback
      end

      if comment.withdrawn?
        @rejection_reason = RejectionReason::Withdrawn

        AppDatabase.rollback
      end

      vote_counts = Hash(String, Int32).from_json(comment.vote_counts.to_json)

      unless vote_counts.has_key?(vote_type)
        @rejection_reason = RejectionReason::InvalidVoteType

        AppDatabase.rollback
      end

      voted_types = toggle_vote_and_update_counts(comment)
    end

    return nil unless transaction_committed

    {vote_counts: vote_counts, voted_types: voted_types}
  end

  private def toggle_doc_vote(doc_id : Int64) : NamedTuple(vote_counts: Hash(String, Int32), voted_types: Array(String))?
    vote_counts = {} of String => Int32
    voted_types = [] of String

    transaction_committed = AppDatabase.transaction do
      doc = DocQuery.new.id(doc_id).content.is_not_nil.for_update.first
      vote_counts = Hash(String, Int32).from_json(doc.vote_counts.to_json)

      unless vote_counts.has_key?(vote_type)
        @rejection_reason = RejectionReason::InvalidVoteType

        AppDatabase.rollback
      end

      voted_types = toggle_vote_and_update_counts(doc)
    end

    return nil unless transaction_committed

    {vote_counts: vote_counts, voted_types: voted_types}
  end

  # 点赞时移除点踩，点踩时移除点赞，并递减对应计数。
  private def remove_opposite_vote(votes : VoteQuery, vote_counts : Hash(String, Int32)) : Nil
    return unless vote_type.in?("👍", "👎")

    opposite_type = vote_type == "👍" ? "👎" : "👍"

    if (opposite_vote = votes.vote_type(opposite_type).first?)
      DeleteVote.delete!(opposite_vote)

      vote_counts[opposite_type] -= 1
    end
  end

  # 按目标变量名称生成投票切换及计数保存代码，返回用户投过的表情。
  private macro toggle_vote_and_update_counts(record)
    {% foreign_key = "#{record.id}_id".id %}

    begin
      %votes = VoteQuery.new.user_id(user_id).{{ foreign_key }}({{ record }}.id)

      if (%vote = %votes.vote_type(vote_type).first?)
        DeleteVote.delete!(%vote)

        vote_counts[vote_type] -= 1
      else
        remove_opposite_vote(%votes, vote_counts)

        SaveVote.create!(
          user_id: user_id,
          {{ foreign_key }}: {{ record }}.id,
          vote_type: vote_type
        )

        vote_counts[vote_type] += 1
      end

      {{ "Update#{record.stringify.capitalize.id}VoteCounts".id }}.update!(
        {{ record }},
        vote_counts: {{ record.stringify.capitalize.id }}::VoteCounts.from_json(vote_counts.to_json)
      )

      %votes.map(&.vote_type)
    end
  end
end
