module StepsControllers
  class ProfileStepsController < ApplicationController
    include Wicked::Wizard

    steps *Profile.form_steps.keys

    def show
      @profile = Profile.find(params[:profile_id])
      #raise params.inspect
      render_wizard
    end

    def update
      @profile = Profile.find(params[:profile_id])
      # Use #assign_attributes since render_wizard runs a #save for us
      @profile.assign_attributes profile_params
      render_wizard @profile
    end

    private

    # Only allow the params for specific attributes allowed in this step
    def profile_params
      params.require(:profile).permit(Profile.form_steps[step]).merge(form_step: step.to_sym)
    end

    def finish_wizard_path
      profile_path(@profile)
    end
  end
end