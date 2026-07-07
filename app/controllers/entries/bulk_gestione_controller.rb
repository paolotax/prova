module Entries
  class BulkGestioneController < ApplicationController
    def show
      entries = Current.account.entries.where(id: params[:ids]).includes(:entryable)
      documento_ids = entries.select { |e| e.entryable_type == "Documento" }.map(&:entryable_id)

      @documenti = Current.account.documenti
        .where(id: documento_ids)
        .includes(:causale, :consegne, :pagamenti, :clientable, :righe)
        .order(:clientable_type, :clientable_id, :data_documento)

      @documenti_per_cliente = @documenti.group_by(&:clientable)

      respond_to do |format|
        format.turbo_stream { render "documenti/bulk_gestione/show" }
        format.html { render "documenti/bulk_gestione/show", layout: false }
      end
    end
  end
end
