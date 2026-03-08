module DateInputHelper
  # Renders a date input with dd/mm/yyyy display format, native picker fallback,
  # and hidden ISO field for form submission.
  #
  # Works with form builder:
  #   date_input(form, :data_tappa)
  #   date_input(form, :data_tappa, value: Date.today, style: "max-width: 16ch;")
  #
  # Works standalone (tag-style):
  #   date_input_tag(:giorno, @giorno, name: "giorno")
  #   date_input_tag(:giorno, @giorno, name: "giorno", form: "external_form_id")
  #
  def date_input(form, method, **options)
    override = options.delete(:value)
    value = override.nil? ? form.object&.public_send(method) : override
    iso = value.present? ? value.to_date.iso8601 : ""
    display = value.present? ? value.to_date.strftime("%d/%m/%Y") : ""
    input_name = "#{form.object_name}[#{method}]"
    input_class = class_names("input input--date", options.delete(:class))

    date_input_markup(input_name, iso, display, input_class, **options)
  end

  def date_input_tag(method, value = nil, **options)
    iso = value.present? ? value.to_date.iso8601 : ""
    display = value.present? ? value.to_date.strftime("%d/%m/%Y") : ""
    input_name = options.delete(:name) || method.to_s
    input_class = class_names("input input--date", options.delete(:class))

    date_input_markup(input_name, iso, display, input_class, **options)
  end

  private

  def date_input_markup(input_name, iso, display, input_class, **options)
    wrapper_style = options.delete(:style)
    form_id = options.delete(:form)
    input_id = options.delete(:id)

    tag.div(data: { controller: "date-input" }, class: "date-input", style: wrapper_style) do
      safe_join([
        tag.input(
          type: "text",
          value: display,
          placeholder: "gg/mm/aaaa",
          inputmode: "numeric",
          autocomplete: "off",
          class: input_class,
          data: {
            date_input_target: "display",
            action: "input->date-input#parseText blur->date-input#formatOnBlur"
          }
        ),
        tag.input(
          type: "date",
          value: iso,
          class: "date-input__picker",
          tabindex: -1,
          "aria-hidden": true,
          data: {
            date_input_target: "picker",
            action: "change->date-input#pickerChanged"
          }
        ),
        tag.input(
          type: "hidden",
          name: input_name,
          id: input_id,
          value: iso,
          form: form_id,
          data: { date_input_target: "hidden" }
        ),
        tag.button(
          type: "button",
          class: "date-input__trigger",
          tabindex: -1,
          "aria-label": "Apri calendario",
          data: { action: "date-input#openPicker" }
        ) { icon_tag("calendar", class: "w-5 h-5") }
      ])
    end
  end
end
