# frozen_string_literal: true

# Base project component class
class ApplicationComponent < ViewComponent::Base
  #include WithStimulusControllerComponent

  # Unique component CSS class name
  class << self
    def component_class
      name.underscore.tr("/", "-")
    end

    # Default component HTML attributes
    def default_html_attributes = { class: component_class }

    def concat_html_attributes(old_html_attributes, new_html_attributes)
      old_html_attributes.merge(new_html_attributes) do |_key, oldval, newval|
        case oldval
        when String then "#{oldval} #{newval}"
        when Hash then concat_html_attributes(oldval, newval)
        else newval
        end
      end
    end
  end

  attr_reader :wrapper_attributes

  delegate_missing_to :helpers
  delegate :component_class, :default_html_attributes, :concat_html_attributes, to: :class

  def initialize(html_attributes: {})
    @wrapper_attributes = concat_html_attributes(default_html_attributes, html_attributes)
    super
  end
end