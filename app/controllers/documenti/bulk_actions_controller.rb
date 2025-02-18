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
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      
      # Raggruppa i documenti per clientable
      @documenti.group_by { |d| [d.clientable_type, d.clientable_id] }.each do |(_type, _id), docs|
        # Crea un nuovo documento per ogni gruppo
        nuovo_documento = current_user.documenti.create(
          causale: docs.first.causale,
          clientable: docs.first.clientable,
          referente: docs.first.referente,
          note: [
            docs.map(&:note).compact.join("\n"),
            "\nDocumenti uniti:",
            docs.map { |d| "- Nr. #{d.numero_documento} del #{I18n.l(d.data_documento)}" }.join("\n")
          ].join("\n"),
          data_documento: Date.current,
          numero_documento: current_user.documenti
                            .where(causale: docs.first.causale)
                            .where('EXTRACT(YEAR FROM data_documento) = ?', Date.current.year)
                            .maximum(:numero_documento).to_i + 1
        )

        # Aggiungi tutte le righe uniche al nuovo documento
        docs.flat_map(&:documento_righe).uniq { |dr| dr.riga_id }.each.with_index(1) do |dr, index|
          nuovo_documento.documento_righe.create(
            riga: dr.riga,
            posizione: index
          )
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Documenti uniti con successo" }
      end
    end

    def destroy_all
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      @documenti.destroy_all

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "Documenti eliminati con successo" }
      end
    end

    private

    def bulk_action_params
      params.permit(:documento_ids)
    end
  end
end