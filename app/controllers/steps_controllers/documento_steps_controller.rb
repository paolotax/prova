module StepsControllers
  class DocumentoStepsController < ApplicationController
    include Wicked::Wizard

    steps *Documento.form_steps.keys

    def show
      @documento = Documento.find(params[:documento_id])
      #raise params.inspect
      render_wizard
    end

    def update
      @documento = Documento.find(params[:documento_id])
      # Use #assign_attributes since render_wizard runs a #save for us
      @documento.assign_attributes documento_params
      render_wizard @documento
    end

    private

    # Only allow the params for specific attributes allowed in this step
    def documento_params
      params.require(:documento).permit(Documento.form_steps[step]).merge(form_step: step.to_sym)
    end

    def finish_wizard_path
      documento_path(@documento)
    end
  end
end