class UpdateCommentVoteCounts < Comment::SaveOperation
  permit_columns vote_counts
end
