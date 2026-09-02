class UpdateReplyVoteCounts < Reply::SaveOperation
  permit_columns vote_counts
end
