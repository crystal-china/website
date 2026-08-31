class MakeReplyFloorRequired::V20260830120300 < Avram::Migrator::Migration::V1
  def migrate
    make_required table_for(Reply), :floor
  end

  def rollback
    make_optional table_for(Reply), :floor
  end
end
