# frozen_string_literal: true

module Documenti
  class DerivazioniController < ApplicationController
    before_action :set_documento

    # POST /documenti/:documento_id/derivazione
    def create
      @derivato = if params[:modalita] == "esistente" && params[:documento_esistente_id].present?
        aggiungi_a_esistente
      else
        crea_nuovo_derivato
      end

      respond_to do |format|
        format.html { redirect_to documento_path(@derivato), notice: "Documento registrato" }
        format.turbo_stream { redirect_to documento_path(@derivato) }
      end
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def crea_nuovo_derivato
      causale = current_account.causali.find(params[:causale_id])

      unless @documento.puo_generare_da_causale?(causale)
        raise ActiveRecord::RecordInvalid, "Causale non valida per derivazione"
      end

      @documento.genera_documento_derivato(causale, {
        numero_documento: params[:numero_documento],
        data_documento: Date.today
      })
    end

    def aggiungi_a_esistente
      target = current_account.documenti.find(params[:documento_esistente_id])
      @documento.aggiungi_righe_a(target)
      target
    end
  end
end
