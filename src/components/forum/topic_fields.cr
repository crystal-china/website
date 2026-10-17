@[Rosetta::Translatable::Config(prefix: "forum.topic_fields")]
class Forum::TopicFields(T) < BaseComponent
  needs operation : T
  needs nodes : Array(Node)

  def render(&) : Nil
    node_id_attribute = operation.node_id

    div class: "grid gap-6 sm:grid-cols-[12rem_minmax(0,1fr)] sm:gap-4" do
      div class: "form-field" do
        label_for node_id_attribute, r("common.node").t, class: "form-label"

        select_input node_id_attribute, attrs: [:required], class: "form-input" do
          select_prompt r(".choose_node").t
          options_for_select node_id_attribute, nodes.map { |node| {node.name, node.id} }
        end

        mount Shared::FieldErrors, node_id_attribute
      end

      mount Shared::Field, attribute: operation.title, label_text: r("fields.title").t, &.text_input(autofocus: "true", required: "")
    end

    div class: "form-field" do
      label r("fields.content").t, for: "topic_text_area", class: "form-label"

      mount(
        Comments::Editor,
        content: operation.content.value || "",
        current_user: current_user,
        html_id: "topic",
        editor_height: "h-[24rem] min-h-[24rem] max-h-[60rem]"
      ) do
        yield
      end

      mount Shared::FieldErrors, operation.content
    end
  end
end
