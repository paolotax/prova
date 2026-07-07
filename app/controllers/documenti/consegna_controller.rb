# frozen_string_literal: true

module Documenti
  class ConsegnaController < ApplicationController
    include ActionView::RecordIdentifier

    before_action :set_documento

    # POST /documenti/:documento_id/consegna
    # params[:righe] opzionale: { documento_riga_id => quantita } per consegna parziale
    def create
      if params[:righe].present?
        @documento.consegna_parziale!(params[:righe].to_unsafe_h, consegnato_il: parsed_date(:consegnato_il))
      else
        @documento.mark_consegnato(consegnato_il: parsed_date(:consegnato_il))
      end

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json { render json: { ok: true, consegnato: @documento.consegnato?, consegnato_il: @documento.consegnato_il } }
      end
    end

    # PATCH /documenti/:documento_id/consegna
    def update
      @documento.consegne.order(:consegnato_il).last&.update!(consegnato_il: parsed_date(:consegnato_il))

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json { render json: { ok: true, consegnato: @documento.consegnato?, consegnato_il: @documento.consegnato_il } }
      end
    end

    # DELETE /documenti/:documento_id/consegna
    def destroy
      @documento.unmark_consegnato
      @documento.reload

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json { render json: { ok: true, consegnato: false } }
      end
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def parsed_date(param)
      return nil unless params[param].present?
      Date.parse(params[param])
    rescue ArgumentError
      Date.today
    end

    def render_container_replacement
      render turbo_stream: [
        turbo_stream.replace(
          dom_id(@documento, :meta),
          partial: "documenti/display/perma/meta",
          locals: { documento: @documento }
        ),
        turbo_stream.replace(
          dom_id(@documento, :gestione_dialog),
          partial: "documenti/container/gestione_dialog_content",
          locals: { documento: @documento }
        )
      ]
    end
  end
end
