# frozen_string_literal: true

module Documenti
  class DerivazioneController < ApplicationController
    before_action :set_documento

    # POST /documenti/:documento_id/derivazione
    def create
      @derivato = if params[:modalita] == "esistente" && params[:documento_esistente_id].present?
        aggiungi_a_esistente
      else
        crea_nuovo_derivato
      end

      redirect_to documento_path(@derivato), notice: "Documento registrato"
    end

    private

    def set_documento
      @documento = current_account.documenti.find(params[:documento_id])
    end

    def crea_nuovo_derivato
      causale = Causale.find(params[:causale_id])
      numero = params[:numero_documento].presence || prossimo_numero(causale)

      derivato = @documento.genera_documento_derivato(causale, {
        numero_documento: numero,
        data_documento: Date.today,
        account: current_account
      })

      derivato.save!

      # Ricalcola i totali (reload per avere le righe aggiornate)
      derivato.reload
      derivato.ricalcola_totali!

      # Crea entry per il nuovo documento (aperto)
      derivato.ensure_entry!

      # Il documento origine diventa "figlio" del nuovo documento
      @documento.update!(documento_padre_id: derivato.id)

      # Chiude il documento origine
      @documento.ensure_entry!
      @documento.close unless @documento.closed?

      derivato
    end

    def prossimo_numero(causale)
      anno_corrente = Date.current.year
      ultimo = current_account.documenti
        .where(causale: causale)
        .where("EXTRACT(YEAR FROM data_documento) = ?", anno_corrente)
        .maximum(:numero_documento)

      (ultimo || 0) + 1
    end

    def aggiungi_a_esistente
      target = current_account.documenti.find(params[:documento_esistente_id])
      @documento.aggiungi_righe_a(target)
      target
    end
  end
end
