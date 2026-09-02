class UpdateDocVoteCounts < Doc::SaveOperation
  permit_columns vote_counts
end
