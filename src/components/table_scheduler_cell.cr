class TableSchedulerCell < BaseComponent
  needs date : String
  needs hour : String
  needs available : Bool
  needs comment : String?

  def render : Nil
    me = current_user
    cell_hour_time = Time.parse("#{date} #{hour}:59", "%Y-%m-%d %H:%M", Time::Location.load("Asia/Shanghai"))
    expired = Time.local > cell_hour_time
    admin = me.try(&.admin?) || false

    opts = {
      class: expired ? "disabled" : "",
    }

    if admin
      opts = opts.merge(data_tooltip: comment.to_s) if comment.present?
    end

    td(opts) do
      if admin && !expired
        button(
          available? ? "🟢" : "🔴",
          type: "button",
          class: "block w-full",
          "aria-label": r(".edit_reservation").t(date: date, hour: hour),
          hx_post: Htmx::HourlySchedule.path_without_query_params,
          hx_prompt: r(".reservation_prompt").t(date: date, hour: hour),
          hx_target: "closest td",
          hx_swap: "outerHTML",
          hx_vals: %({"date": "#{date}", "hour": "#{hour}"})
        )
      else
        text available? ? "🟢" : "🔴"
      end
    end
  end
end
