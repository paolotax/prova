module Documenti
  class BulkStatiController < ApplicationController
    def create
      @documenti = current_account.documenti
        .where(id: params[:ids])
        .includes(:causale, :consegna, :pagamento, :clientable, :righe, :entry)

      case params[:azione]
      when "completa"
        @documenti.each do |d|
          entry = d.ensure_entry!
          entry.close unless entry.closed?
        end
      when "riapri"
        @documenti.each do |d|
          d.entry&.reopen if d.entry&.closed?
        end
      when "triage"
        column = current_account.columns.find(params[:column_id])
        @documenti.each do |d|
          entry = d.ensure_entry!
          entry.triage_into(column)
        end
      end

      @documenti.each(&:reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: documenti_path }
      end
    end
  end
end
