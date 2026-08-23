module AuthPageHelpers
  def auth_card(title : String, description : String, &)
    article class: "w-full overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
      header class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
        h1 title, class: "text-3xl font-semibold tracking-tight text-gray-900"
        para description, class: "mt-2 text-sm leading-6 text-gray-600"
      end

      yield
    end
  end

  def auth_page_with_oauth(&)
    section class: "mx-auto grid w-full max-w-4xl gap-8 px-8 py-12 lg:grid-cols-[minmax(0,1fr)_18rem]" do
      yield
      mount Component::OAuth
    end
  end

  def auth_page_single_column(&)
    section class: "mx-auto w-full max-w-3xl px-8 py-12" do
      yield
    end
  end

  def auth_form_fields(&)
    div class: "mx-auto w-full max-w-sm space-y-6" do
      yield
    end
  end

  def auth_form_actions(justify : String = "justify-between", &)
    div class: "flex flex-wrap items-center #{justify} gap-3 border-t border-gray-200 pt-6" do
      yield
    end
  end
end
