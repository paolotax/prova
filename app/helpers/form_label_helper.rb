module FormLabelHelper
  # This helper allows to render labels in a more terse way.
  # Instead of `<%= render(FormLabelComponent.new(form: form, field: "email")) %>`
  # write `<%= label_for form: form, field: "email" %>`,
  #
  def label_for(form:, field:, label: nil)
    render(FormLabelComponent.new(form: form, field: field, label: label))
  end
end
