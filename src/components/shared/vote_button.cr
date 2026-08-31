class Shared::VoteButton < BaseComponent
  needs reply_id : Int64?
  needs doc_id : Int64?
  needs votes : Hash(String, Int32)
  needs voted_types : Array(String)

  def render
    votes.each do |(emoji, count)|
      gray = count == 0 ? "grayscale-[50%] text-gray-300" : ""
      voted = emoji.in?(voted_types) ? "border border-black" : "border-transparent"
      config = {
        class: "inline-flex h-6 min-w-11 items-center justify-center gap-1 whitespace-nowrap rounded-full border bg-transparent px-2.5 text-sm leading-none #{gray} #{voted}",
        type:  "button",
      }

      if current_user
        if reply_id
          hx_values = %({"user_id": #{current_user.not_nil!.id}, "vote_type": "#{emoji}", "reply_id": #{reply_id.not_nil!}})
        else
          hx_values = %({"user_id": #{current_user.not_nil!.id}, "vote_type": "#{emoji}", "doc_id": #{doc_id.not_nil!}})
        end

        config = config.merge(
          {
            hx_patch:  Htmx::Docs::Vote.path_without_query_params,
            hx_vals:   hx_values,
            hx_target: "closest div",
          },
        )
      end

      button(config) do
        span emoji, class: "inline-block leading-none"
        span count, class: "inline-block leading-none"
      end
    end
  end
end
