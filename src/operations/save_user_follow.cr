class SaveUserFollow < UserFollow::SaveOperation
  upsert_lookup_columns :followed_user_id, :follower_id

  before_save do
    validate_required followed_user_id, follower_id

    if follower_id.value && follower_id.value == followed_user_id.value
      follower_id.add_error r("validations.cannot_follow_self").t
    end
  end
end
