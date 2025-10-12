require 'combine_pdf'
require 'tempfile'

module Documenti
  class BulkActionsController < ApplicationController
    before_action :authenticate_user!

    def print_all
      # Crea un nuovo PDF combinato
      combined_pdf = CombinePDF.new

      # Per ogni documento, crea un PDF singolo e aggiungilo al PDF combinato
      params[:documento_ids].each do |documento_id|
        documento = Documento.find(documento_id)

        # Genera il PDF per il singolo documento
        pdf = DocumentoPdf.new(documento, view_context)

        # Salva temporaneamente il PDF
        temp_file = Tempfile.new(['documento', '.pdf'])
        pdf.render_file(temp_file.path)

        # Aggiungi il PDF al documento combinato
        combined_pdf << CombinePDF.load(temp_file.path)

        # Chiudi e elimina il file temporaneo
        temp_file.close
        temp_file.unlink
      end

      # Invia il PDF combinato come risposta
      send_data combined_pdf.to_pdf,
                filename: "documenti_#{Time.current.strftime('%Y%m%d')}.pdf",
                type: 'application/pdf',
                disposition: 'inline'
    end

    def duplica
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      @documenti_creati = []

      @documenti.each do |documento|
        nuovo_documento = current_user.documenti.create(
          causale: documento.causale,
          clientable: documento.clientable,
          referente: documento.referente,
          note: documento.note,
          data_documento: Date.current,
          numero_documento: current_user.documenti
                            .where(causale: documento.causale)
                            .where('EXTRACT(YEAR FROM data_documento) = ?', Date.current.year)
                            .maximum(:numero_documento).to_i + 1
        )

        documento.documento_righe.each do |riga|
          nuovo_documento.documento_righe.create(
            riga: riga.riga.dup
          )
        end
        @documenti_creati << nuovo_documento
      end

      notice = helpers.pluralize(@documenti_creati.count, 'documento duplicato', 'documenti duplicati')

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
        end
        format.html { redirect_to documenti_path, notice: notice }
      end
    end

    def unisci
      documenti_per_cliente = current_user.documenti
                                        .where(id: params[:documento_ids])
                                        .order(:data_documento)
                                        .group_by(&:clientable)

      @documenti_originali = []
      @documenti_creati = []
      @documento_unito = nil

      documenti_per_cliente.each do |clientable, documenti|
        @documenti_originali.concat(documenti)
        documento_base = documenti.first

        @documento_unito = current_user.documenti.create(
          causale_id: params[:causale_id] || documento_base.causale_id,
          clientable: clientable,
          referente: documento_base.referente,
          data_documento: Date.current,
          numero_documento: current_user.documenti
                            .where(causale_id: params[:causale_id] || documento_base.causale_id)
                            .where('EXTRACT(YEAR FROM data_documento) = ?', Date.current.year)
                            .maximum(:numero_documento).to_i + 1,
          note: "Riferimento documenti:\n #{documenti.map { |d| "#{d.causale} nr.#{d.numero_documento} del #{d.data_documento.strftime('%d/%m/%Y')}" }.join("\n")}",
          status: params[:status] || documento_base.status,
          tipo_pagamento: params[:tipo_pagamento] || documento_base.tipo_pagamento,
          pagato_il: params[:pagato_il] || documento_base.pagato_il,
          consegnato_il: params[:consegnato_il] || documento_base.consegnato_il
        )

        documenti.flat_map(&:documento_righe).uniq { |dr| dr.riga_id }.each.with_index(1) do |dr, index|
          @documento_unito.documento_righe.create(
            riga: dr.riga,
            posizione: index
          )
        end

        # Imposta il documento_padre_id per tutti i documenti selezionati
        documenti.each do |documento|
          documento.update(documento_padre_id: @documento_unito.id)
        end

        @documenti_creati << @documento_unito
      end

      notice = helpers.pluralize(@documenti_creati.count, 'documento generato', 'documenti generati')

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
        end
        format.html { redirect_to documenti_path, notice: notice }
      end
    end

    def destroy_all
      @ids = params[:documento_ids]

      @documenti = current_user.documenti.where(id: @ids)
      @documenti.destroy_all

      notice = helpers.pluralize(@ids.count, "documento eliminato", "documenti eliminati")

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
        end
        format.html { redirect_to documenti_path, notice: notice }
      end
    end

    def update_stato
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      count = @documenti.load.size

      @documenti.each do |documento|
        documento.update(stato_params.compact)
      end

      notice = "Stato aggiornato per #{helpers.pluralize(count, 'documento', 'documenti')}"
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
        end
        format.html { redirect_to documenti_path, notice: notice }
      end
    end

    private

    def bulk_action_params
      params.permit(:documento_ids)
    end

    def stato_params
      params.permit(:status, :tipo_pagamento, :pagato_il, :consegnato_il)
    end
  end
end