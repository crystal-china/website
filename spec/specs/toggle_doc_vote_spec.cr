require "../spec_helper"

describe ToggleVote do
  it "keeps the three document reactions and their existing counts" do
    counts = Doc::VoteCounts.from_json(%({"👍":2,"👎":1,"❤️":3}))
    serialized = Hash(String, Int32).from_json(counts.to_json)

    serialized.should eq({
      "👍"  => 2,
      "👎"  => 1,
      "❤️" => 3,
    })
    serialized.keys.should eq(["👍", "👎", "❤️"])
  end

  it "rejects comment-only reactions on documents without creating votes" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/doc-reaction-types", "正文")

    ["😄", "🎉", "😕", "👀️"].each do |vote_type|
      ToggleVote.run(
        doc_id: doc.id,
        user_id: user.id,
        vote_type: vote_type
      ) do |operation, result|
        result.should be_nil
        operation.rejection_reason.should eq(ToggleVote::RejectionReason::InvalidVoteType)
      end

      VoteQuery.new.doc_id(doc.id).any?.should be_false
      Hash(String, Int32).from_json(doc.reload.vote_counts.to_json).values.should eq([0, 0, 0])
    end
  end

  it "switches and cancels thumbs while preserving hearts and other users' votes" do
    user = UserFactory.create
    other = UserFactory.create
    doc = DocContent.sync("/docs/toggle-doc-vote", "")

    [user, other].each do |voter|
      ToggleVote.run!(
        doc_id: doc.id,
        user_id: voter.id,
        vote_type: "👎"
      )
    end

    ToggleVote.run!(
      doc_id: doc.id,
      user_id: user.id,
      vote_type: "❤️"
    )

    result = ToggleVote.run!(
      doc_id: doc.id,
      user_id: user.id,
      vote_type: "👍"
    )

    result[:voted_types].sort.should eq(["👍", "❤️"].sort)
    result[:vote_counts]["👍"].should eq(1)
    result[:vote_counts]["👎"].should eq(1)
    result[:vote_counts]["❤️"].should eq(1)
    VoteQuery.new.doc_id(doc.id).user_id(other.id).map(&.vote_type).should eq(["👎"])
    doc.reload.vote_counts.👍.should eq(1)
    doc.reload.vote_counts.👎.should eq(1)
    doc.reload.vote_counts.❤️.should eq(1)

    result = ToggleVote.run!(
      doc_id: doc.id,
      user_id: user.id,
      vote_type: "👍"
    )

    result[:voted_types].should eq(["❤️"])
    result[:vote_counts]["👍"].should eq(0)
    VoteQuery.new.doc_id(doc.id).user_id(user.id).map(&.vote_type).should eq(["❤️"])
    doc.reload.vote_counts.👍.should eq(0)
    doc.reload.vote_counts.👎.should eq(1)
    doc.reload.vote_counts.❤️.should eq(1)
    doc.reload.content.should eq(doc.content)
    doc.reload.content_updated_at.should eq(doc.content_updated_at)
  end

  it "rejects invalid types and missing documents without changing existing votes" do
    user = UserFactory.create
    doc = DocContent.sync("/docs/toggle-doc-vote-rejected", "正文")

    ToggleVote.run!(
      doc_id: doc.id,
      user_id: user.id,
      vote_type: "👍"
    )

    vote = VoteQuery.new.doc_id(doc.id).first

    ToggleVote.run(
      doc_id: doc.id,
      user_id: user.id,
      vote_type: "invalid"
    ) do |_operation, result|
      result.should be_nil
    end

    expect_raises(Avram::RecordNotFoundError) do
      ToggleVote.run!(
        doc_id: 0_i64,
        user_id: user.id,
        vote_type: "👍"
      )
    end

    SaveDoc.update!(doc, content: nil)

    expect_raises(Avram::RecordNotFoundError) do
      ToggleVote.run!(
        doc_id: doc.id,
        user_id: user.id,
        vote_type: "👎"
      )
    end

    VoteQuery.new.doc_id(doc.id).map(&.id).should eq([vote.id])
    doc.reload.vote_counts.👍.should eq(1)
    doc.reload.vote_counts.👎.should eq(0)
  end
end
