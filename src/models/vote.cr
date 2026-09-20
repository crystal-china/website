class Vote < BaseModel
  table do
    belongs_to user : User
    belongs_to comment : Comment?
    belongs_to doc : Doc?
    polymorphic target, associations: [:comment, :doc]

    column vote_type : String
  end
end
