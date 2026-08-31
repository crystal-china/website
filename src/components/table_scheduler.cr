class TableScheduler < BaseComponent
  needs year : Int32
  needs month : Int32

  def render
    today = Time.local.day

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
          (1..31).each do |date_number|
            date = Time.local(year, month, date_number, location: Time::Location.load("Asia/Shanghai")).to_s("%Y-%m-%d")

            tr class: today > date_number ? "disabled" : "" do
              td date_number

              HourlyAvailabilityQuery.new.date(date).hour.asc_order.each do |record|
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
