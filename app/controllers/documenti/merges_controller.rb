# frozen_string_literal: true

module Documenti
  class MergesController < ApplicationController
    def create
      documenti_per_cliente = current_account.documenti
                                             .where(id: params[:ids])
                                             .order(:data_documento)
                                             .group_by(&:clientable)

      @documenti_originali = []
      @documenti_creati = []

      documenti_per_cliente.each do |clientable, documenti|
        @documenti_originali.concat(documenti)
        documento_base = documenti.first

        documento_unito = current_account.documenti.create!(
          user: Current.user,
          causale_id: params[:causale_id] || documento_base.causale_id,
          clientable: clientable,
          referente: documento_base.referente,
          data_documento: Date.current,
          numero_documento: current_account.documenti
                            .where(causale_id: params[:causale_id] || documento_base.causale_id)
                            .where("EXTRACT(YEAR FROM data_documento) = ?", Date.current.year)
                            .maximum(:numero_documento).to_i + 1,
          note: "Riferimento documenti:\n #{documenti.map { |d| "#{d.causale} nr.#{d.numero_documento} del #{d.data_documento.strftime('%d/%m/%Y')}" }.join("\n")}",
          status: params[:status] || documento_base.status,
          tipo_pagamento: params[:tipo_pagamento] || documento_base.tipo_pagamento,
          pagato_il: params[:pagato_il] || documento_base.pagato_il,
          consegnato_il: params[:consegnato_il] || documento_base.consegnato_il
        )

        # Usa insert_all per evitare le callback durante il merge
        righe_uniche = documenti.flat_map(&:documento_righe).uniq { |dr| dr.riga_id }
        righe_data = righe_uniche.map.with_index(1) do |dr, index|
          {
            documento_id: documento_unito.id,
            riga_id: dr.riga_id,
            posizione: index,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        DocumentoRiga.insert_all(righe_data) if righe_data.any?

        documento_unito.reload
        documento_unito.ricalcola_totali!

        # Crea entry per il documento unificato (aperto)
        documento_unito.ensure_entry!

        # I documenti originali diventano figli e vengono chiusi
        documenti.each do |documento|
          documento.update!(documento_padre_id: documento_unito.id)
          documento.ensure_entry!
          documento.close unless documento.closed?
        end

        @documenti_creati << documento_unito
      end

      notice = "#{@documenti_creati.count} #{@documenti_creati.count == 1 ? 'documento generato' : 'documenti generati'}"

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: notice }
      end
    end
  end
end
