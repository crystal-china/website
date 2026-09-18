class Db::Seed::HourlyAvailability < LuckyTask::Task
  summary "Add hourly availability initialize data"
  arg :year, "Year to initialize", optional: true, format: /^\d{4}$/
  arg :month, "Month to initialize", optional: true, format: /^(?:[1-9]|1[0-2])$/

  def call
    now = Time.local
    target_year = year.try(&.to_i) || now.year
    target_month = month.try(&.to_i) || now.month

    Db::Seed::HourlyAvailabilityTask.run(target_year, target_month)
  end
end

module Db::Seed::HourlyAvailabilityTask
  def self.run(year, month)
    start_day = 1
    end_day = Time.local(year, month, 1).at_end_of_month.day

    # HourlyAvailabilityQuery.truncate

    (start_day..end_day).each do |day|
      date = Time.local(year, month, day).to_s("%Y-%m-%d")

      ["09", "10", "11", "12", "13", "14", "15", "16", "17"].each do |hour|
        SaveHourlyAvailability.upsert!(
          date: date,
          hour: hour
        )
      end
    end
  end
end
