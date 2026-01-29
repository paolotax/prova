# frozen_string_literal: true

class Documenti::StatusesController < ApplicationController
  include DocumentoScoped

  # GET /documenti/:documento_id/status/edit
  def edit
    @field = params[:field]
    render partial: "documenti/edit_status_modal", locals: { documento: @documento, field: @field }
  end

  # PATCH /documenti/:documento_id/status
  def update
    if @documento.update(status_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @documento }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def status_params
    params.require(:documento).permit(:status, :consegnato_il, :pagato_il)
  end
end
