# frozen_string_literal: true

module Common
  class MultistepFormComponent < ApplicationComponent
    class << self
      def steps = raise "#{name} MultistepFormComponent does not define steps class model"
    end

    delegate :steps, to: :class

    attr_reader :form_url, :back_url, :model, :form

    def initialize(form_url:, back_url:, model:, html_attributes: {})
      @form_url = form_url
      @back_url = back_url
      @model = model
      clear_next_steps_errors
      super(html_attributes:)
    end

    def call
      form_with(url: form_url, model: model, **wrapper_attributes) do |form|
        @form = form

        concat(form.hidden_field(:total_steps, value: steps.count))
        concat(form.hidden_field(:latest_step, value: latest_step_index))
        concat(form.hidden_field(:current_step, value: current_step_index))

        steps.each_with_index do |step, index|
          concat(step_wrapper(step, index) { render step.new(multistep_component: self, index:) })
        end
      end
    end

    def radio_id(step_index) = "#{object_id}_radio_#{step_index}"

    def checkbox_id(step_index) = "#{object_id}_radio_#{step_index}"

    def step_wrapper(step, index, html_attributes: {}, &content)
      tag.div(**html_attributes) do
        concat(
          radio_button_tag(
            radio_id(nil),
            1,
            current_step_index == index,
            id: radio_id(index),
            class: "hidden peer/radio"
          )
        )
        concat(
          check_box_tag(
            checkbox_id(index),
            1,
            current_step_index == index,
            id: checkbox_id(index),
            class: "hidden peer/checkbox"
          )
        )
        concat(capture(&content))
      end
    end

    def first_incompleted_step_index
      steps.find_index { |s| !s.completed?(model) }
    end

    def current_step_index
      previous_step = model.current_step&.to_i

      @current_step_index =
        if model.current_step.nil?
          0
        else
          next_step = previous_step + (steps[previous_step].completed?(model) ? 1 : 0)
          [next_step, first_incompleted_step_index].compact.min
        end
    end

    def latest_step_index
      @latest_step_index =
        if model.latest_step.nil?
          0
        else
          [current_step_index, model.latest_step.to_i].max
        end
    end

    def clear_current_step_error
      return if model.errors.blank?

      model.errors.delete(MultistepFormModel::ERROR_ATTRIBUTE)
    end

    def clear_next_steps_errors
      return if model.errors.blank?

      (steps[(latest_step_index + 1)..] || []).each do |step|
        step.input_attributes.each { |k| model.errors.delete(k) }
      end
    end
  end
end