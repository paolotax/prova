# frozen_string_literal: true

module Documenti
  class BulkDerivazioniController < ApplicationController
    include Documenti::BulkResolvable

    def create
      @causale = Causale.find(params[:causale_id])
      @documenti = bulk_documenti
        .includes(:causale, :consegne, :pagamento, :clientable, :righe, documento_righe: :riga)

      # Filtra solo i documenti la cui causale prevede la causale scelta come successiva
      documenti_validi = @documenti.select { |d| d.puo_generare_da_causale?(@causale) }

      if documenti_validi.empty?
        redirect_back fallback_location: documenti_path,
          alert: "Nessun documento selezionato può generare #{@causale.causale}"
        return
      end

      # Raggruppa per cliente e crea un documento derivato per ciascuno
      @derivati = []

      documenti_validi.group_by(&:clientable).each do |clientable, docs|
        derivato = crea_derivato_unificato(docs, clientable)
        @derivati << derivato
      end

      esclusi = @documenti.size - documenti_validi.size
      notice = @derivati.size == 1 ? "Documento creato" : "#{@derivati.size} documenti creati"
      notice += " (#{esclusi} esclusi)" if esclusi > 0
      redirect_to @derivati.size == 1 ? documento_path(@derivati.first) : documenti_path,
        notice: notice
    end

    private

    def crea_derivato_unificato(documenti_origine, clientable)
      numero = prossimo_numero(@causale)

      derivato = Documento.new(
        causale: @causale,
        derivato_da_causale: documenti_origine.first.causale,
        clientable: clientable,
        user: current_user,
        account: current_account,
        numero_documento: numero,
        data_documento: Date.today,
        status: @causale.stato_iniziale || "bozza"
      )

      # Condividi le righe da tutti i documenti origine (stesse righe, nuovo DocumentoRiga)
      posizione = 0
      documenti_origine.each do |doc_origine|
        doc_origine.documento_righe.each do |doc_riga|
          posizione += 1
          derivato.documento_righe.build(
            riga: doc_riga.riga,
            posizione: posizione
          )
        end
      end

      derivato.save!
      derivato.reload
      derivato.ricalcola_totali!
      derivato.ensure_entry!

      # Imposta ogni documento origine come figlio del derivato e chiudilo
      documenti_origine.each do |doc_origine|
        doc_origine.update!(documento_padre_id: derivato.id)
        doc_origine.ensure_entry!
        doc_origine.close unless doc_origine.closed?
      end

      # Eredita consegna/pagamento dai documenti origine
      derivato.eredita_stato_da_origini(documenti_origine)

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
  end
end
