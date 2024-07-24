# frozen_string_literal: true

class FormLabelComponent < ViewComponent::Base
  def initialize(form:, field:, label: nil)
    @form = form
    @field = field
    @label = label
  end

  erb_template <<-ERB
    <%= @form.label @field, label_value, class: css %>
  ERB

  private

  I18N_PATH = "labels"

  def label_value
    return field_error_message if has_errors?

    @label.presence || default_label_value
  end

  def css
    class_names(
      "text-sm text-gray-700 font-medium",
      {
        "text-red-600": has_errors?
      }
    )
  end

  def field_error_message
    @form.object.errors.full_messages_for(@field).first
  end

  def default_label_value
    I18n.t("#{I18N_PATH}.#{@field}", default: @field.to_s.capitalize)
  end

  def has_errors? = @form.object.errors.full_messages_for(@field).any?
end
