# frozen_string_literal: true

module Documenti
  class ConsegnaController < ApplicationController
    include ActionView::RecordIdentifier

    before_action :set_documento

    # GET /documenti/:documento_id/consegna.pdf — distinta consegnato/residuo
    def show
      respond_to do |format|
        format.pdf do
          pdf = DistintaConsegnePdf.new(@documento, view_context)
          send_data pdf.render, filename: "distinta_consegne_#{@documento.id}.pdf",
                                type: "application/pdf",
                                disposition: "inline"
        end
      end
    end

    # POST /documenti/:documento_id/consegna
    # params[:righe] opzionale: { documento_riga_id => quantita } per consegna parziale
    # params[:righe_libro] opzionale: { isbn o libro_id => quantita } (CLI/API)
    # params[:usa_data_documento] opzionale: consegna in data documento
    def create
      consegnato_il = params[:usa_data_documento].present? ? @documento.data_documento : parsed_date(:consegnato_il)

      if params[:righe].present?
        @documento.consegna_parziale!(params[:righe].to_unsafe_h, consegnato_il: consegnato_il)
      elsif params[:righe_libro].present?
        @documento.consegna_parziale_per_libro!(params[:righe_libro].to_unsafe_h, consegnato_il: consegnato_il)
      else
        @documento.mark_consegnato(consegnato_il: consegnato_il)
      end

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json do
          render json: { ok: true, consegnato: @documento.consegnato?, consegnato_il: @documento.consegnato_il,
                         copie_consegnate: @documento.copie_consegnate, copie_residue: @documento.copie_residue_da_consegnare }
        end
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
    # params[:consegna_id] opzionale: annulla quella consegna, non l'ultima
    def destroy
      consegna = @documento.consegne.find(params[:consegna_id]) if params[:consegna_id].present?
      @documento.unmark_consegnato(consegna)
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
        ),
        turbo_stream.replace(
          dom_id(@documento, :riepiloghi),
          partial: "documenti/container/riepiloghi",
          locals: { documento: @documento }
        )
      ]
    end
  end
end
