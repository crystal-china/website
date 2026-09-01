class Db::Fix::HourlyAvailabilityComments < LuckyTask::Task
  summary "Decode existing hourly availability comments"

  def call
    Db::Fix::HourlyAvailabilityCommentsTask.run
  end
end

module Db::Fix::HourlyAvailabilityCommentsTask
  def self.run
    updated_count = 0

    AppDatabase.transaction do
      HourlyAvailabilityQuery.new.each do |record|
        if (comment = record.comment)
          decoded_comment = URI.decode(comment)
          next if decoded_comment == comment

          SaveHourlyAvailability.update!(record, comment: decoded_comment)
          updated_count += 1
        end
      end
    end

    puts "Done fixing hourly availability comments (#{updated_count} updated)"
  end
end
