module MultistepFormModel 
  


  
  ERROR_ATTRIBUTE = :current_step
  ERROR_DETAIL = :incompleted_multistep_form

  extend ActiveSupport::Concern

  included do
    attr_accessor :current_step, :total_steps, :latest_step

    validate :all_multistep_form_steps_completed,
      if: -> { current_step.present? && total_steps.present? }
  end

  private

  def all_multistep_form_steps_completed? = current_step == total_steps

  def all_multistep_form_steps_completed
    errors.add(ERROR_ATTRIBUTE, ERROR_DETAIL) unless all_multistep_form_steps_completed?
  end
end