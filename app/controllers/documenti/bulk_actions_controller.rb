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
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Nuovi documenti creati con successo" }
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
          causale: documento_base.causale,
          clientable: clientable,
          referente: documento_base.referente,
          data_documento: Date.current,
          numero_documento: current_user.documenti
                            .where(causale: documento_base.causale)
                            .where('EXTRACT(YEAR FROM data_documento) = ?', Date.current.year)
                            .maximum(:numero_documento).to_i + 1,
          note: "Documento unito da: #{documenti.map { |d| "#{d.causale} #{d.numero_documento}" }.join(', ')}"
        )

        documenti.flat_map(&:documento_righe).uniq { |dr| dr.riga_id }.each.with_index(1) do |dr, index|
          @documento_unito.documento_righe.create(
            riga: dr.riga,
            posizione: index
          )
        end
        @documenti_creati << @documento_unito
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Documenti uniti con successo" }
      end
    end

    def destroy_all
      @ids = params[:documento_ids]
      count = @ids.count

      @documenti = current_user.documenti.where(id: @ids)
      @documenti.destroy_all
      
      flash[:notice] = helpers.pluralize(count, "documento eliminato", "documenti eliminati")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Documenti eliminati con successo" }
      end
    end

    def update_stato
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      count = @documenti.count

      @documenti.each do |documento|
        documento.update(stato_params.compact)
      end

      flash[:notice] = "Stato aggiornato per #{helpers.pluralize(count, 'documento', 'documenti')}"
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Stato dei documenti aggiornato con successo" }
      end
    end

    private

    def bulk_action_params
      params.permit(:documento_ids)
    end

    def stato_params
      params.permit(:status, :tipo_pagamento, :pagato_il)
    end
  end
end