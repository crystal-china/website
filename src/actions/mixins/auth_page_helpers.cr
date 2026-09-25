module AuthPageHelpers
  def auth_card(title : String, description : String, &)
    article class: "app-panel w-full overflow-hidden" do
      header class: "panel-header" do
        h1 title, class: "panel-title"
        para description, class: "panel-description"
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
