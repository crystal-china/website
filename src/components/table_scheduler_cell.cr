class TableSchedulerCell < BaseComponent
  needs date : String
  needs hour : String
  needs available : Bool
  needs comment : String?

  def render
    me = current_user
    cell_hour_time = Time.parse("#{date} #{hour}:59", "%Y-%m-%d %H:%M", Time::Location.load("Asia/Shanghai"))
    expired = Time.local > cell_hour_time
    admin = me && me.email == ENV["ADMIN_EMAIL"]?

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
          "aria-label": "修改 #{date} #{hour}:00 的预约",
          hx_post: Htmx::HourlySchedule.path_without_query_params,
          hx_prompt: "修改预约（#{date} #{hour}:00）",
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
