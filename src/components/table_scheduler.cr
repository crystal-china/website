class TableScheduler < BaseComponent
  needs year : Int32
  needs month : Int32

  def render
    location = Time::Location.load("Asia/Shanghai")
    month_start = Time.local(year, month, 1, location: location)
    month_end = month_start.at_end_of_month
    today = Time.local(location: location).to_s("%Y-%m-%d")
    records_by_date = HourlyAvailabilityQuery
      .new
      .date.gte(month_start.to_s("%Y-%m-%d"))
      .date.lte(month_end.to_s("%Y-%m-%d"))
      .results
      .group_by(&.date)

    div class: "table-container" do
      table do
        caption do
          h3 "Hourly Availability table (#{year}/#{month})"
        end

        thead do
          tr do
            th "date\\hour", class: "text-[10px]"
            th "09:00"
            th "10:00"
            th "11:00"
            th "12:00"
            th "13:00"
            th "14:00"
            th "15:00"
            th "16:00"
            th "17:00"
          end
        end

        tbody do
          (1..month_end.day).each do |date_number|
            date = Time.local(year, month, date_number, location: location).to_s("%Y-%m-%d")

            tr class: today > date ? "disabled" : "" do
              td date_number

              records_by_date.fetch(date, [] of HourlyAvailability).sort_by(&.hour).each do |record|
                mount(
                  TableSchedulerCell,
                  date: record.date,
                  hour: record.hour,
                  available: record.available,
                  comment: record.comment,
                  current_user: current_user
                )
              end
            end
          end
        end
      end
    end
  end
end
