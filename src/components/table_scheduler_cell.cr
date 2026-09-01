class TableSchedulerCell < BaseComponent
  needs date : String
  needs hour : String
  needs available : Bool
  needs comment : String?

  def render
    me = current_user

    cell_hour_time = Time.parse("#{date} #{hour}:59", "%Y-%m-%d %H:%M", Time::Location.load("Asia/Shanghai"))
    if Time.local > cell_hour_time
      class_name = "disabled"
    else
      class_name = ""
      hx_prompt = "修改预约（#{date} #{hour}:00）"
      hx_post = Htmx::HourlySchedule.path_without_query_params
    end

    opts = {
      class: class_name,
    }

    if me && me.email == ENV["ADMIN_EMAIL"]?
      opts = opts.merge(
        {
          hx_swap: "outerHTML",
          hx_vals: %({"date": "#{date}", "hour": "#{hour}"}),
        })

      opts = opts.merge(hx_prompt: hx_prompt) if hx_prompt
      opts = opts.merge(hx_post: hx_post) if hx_post

      opts = opts.merge(data_tooltip: comment.to_s) if comment.present?
    end

    td(available? ? "🟢" : "🔴", opts)
  end
end
