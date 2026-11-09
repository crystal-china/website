require "../spec_helper"

private def comment_for_vote_operation : Comment
  author = UserFactory.create
  doc = DocContent.sync("/docs/toggle-comment-vote", "文档正文")

  CreateComment.create!(
    user_id: author.id,
    comment_thread_id: doc.comment_thread!.not_nil!.id,
    content: "评论正文"
  )
end

describe ToggleVote do
  it "requires exactly one target without changing votes or counts" do
    user = UserFactory.create
    comment = comment_for_vote_operation
    doc = comment.comment_thread!.doc.not_nil!

    [{nil, nil}, {comment.id, doc.id}].each do |comment_id, doc_id|
      ToggleVote.run(
        comment_id: comment_id,
        doc_id: doc_id,
        user_id: user.id,
        vote_type: "👍"
      ) do |operation, result|
        result.should be_nil
        operation.rejection_reason.should eq(ToggleVote::RejectionReason::InvalidTarget)
      end
    end

    VoteQuery.new.any?.should be_false
    comment.reload.vote_counts.to_json.should eq(comment.vote_counts.to_json)
    doc.reload.vote_counts.to_json.should eq(doc.vote_counts.to_json)
  end

  it "adds, switches and cancels votes without an HTTP action" do
    user = UserFactory.create
    comment = comment_for_vote_operation

    result = ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👎"
    )

    result[:vote_counts]["👎"].should eq(1)
    result[:voted_types].should eq(["👎"])
    comment.reload.vote_counts.👎.should eq(1)

    result = ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👍"
    )

    result[:vote_counts]["👎"].should eq(0)
    result[:vote_counts]["👍"].should eq(1)
    result[:voted_types].should eq(["👍"])
    VoteQuery.new.comment_id(comment.id).map(&.vote_type).should eq(["👍"])
    comment.reload.vote_counts.👎.should eq(0)
    comment.reload.vote_counts.👍.should eq(1)

    result = ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👍"
    )

    result[:vote_counts]["👍"].should eq(0)
    result[:voted_types].should be_empty
    VoteQuery.new.comment_id(comment.id).any?.should be_false
    comment.reload.vote_counts.👍.should eq(0)
    comment.reload.edited_at.should be_nil
  end

  it "keeps other reactions and other users' votes when switching thumbs" do
    user = UserFactory.create
    other = UserFactory.create
    comment = comment_for_vote_operation

    [user, other].each do |voter|
      ToggleVote.run!(
        comment_id: comment.id,
        user_id: voter.id,
        vote_type: "👎"
      )
    end

    ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "😄"
    )

    result = ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👍"
    )

    result[:voted_types].sort.should eq(["👍", "😄"].sort)
    VoteQuery.new.comment_id(comment.id).user_id(other.id).map(&.vote_type).should eq(["👎"])
    comment.reload.vote_counts.👍.should eq(1)
    comment.reload.vote_counts.👎.should eq(1)
    comment.reload.vote_counts.😄.should eq(1)
  end

  it "rejects invalid types, withdrawn comments and unavailable targets without changing votes" do
    user = UserFactory.create
    comment = comment_for_vote_operation

    ToggleVote.run!(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👍"
    )

    vote = VoteQuery.new.comment_id(comment.id).first

    ToggleVote.run(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "invalid"
    ) do |operation, result|
      result.should be_nil
      operation.rejection_reason.should eq(ToggleVote::RejectionReason::InvalidVoteType)
    end

    Comment::SaveOperation.update!(comment, withdrawn: true)

    ToggleVote.run(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👎"
    ) do |operation, result|
      result.should be_nil
      operation.rejection_reason.should eq(ToggleVote::RejectionReason::Withdrawn)
    end

    Comment::SaveOperation.update!(comment.reload, withdrawn: false)
    SaveDoc.update!(comment.comment_thread!.doc.not_nil!, content: nil)

    ToggleVote.run(
      comment_id: comment.id,
      user_id: user.id,
      vote_type: "👎"
    ) do |operation, result|
      result.should be_nil
      operation.rejection_reason.should eq(ToggleVote::RejectionReason::TargetUnavailable)
    end

    VoteQuery.new.comment_id(comment.id).map(&.id).should eq([vote.id])
    comment.reload.vote_counts.👍.should eq(1)
    comment.reload.vote_counts.👎.should eq(0)
  end
end
