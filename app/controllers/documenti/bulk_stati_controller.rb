module Documenti
  class BulkStatiController < ApplicationController
    include Documenti::BulkResolvable

    def create
      @documenti = bulk_documenti
        .includes(:causale, :consegna, :pagamento, :clientable, :righe, :entry)

      case params[:azione]
      when "completa"
        @documenti.each do |d|
          entry = d.ensure_entry!
          entry.close unless entry.closed?
        end
      when "da_gestire"
        @documenti.each do |d|
          entry = d.ensure_entry!
          entry.send_back_to_triage unless entry.awaiting_triage?
        end
      when "rimanda"
        @documenti.each do |d|
          entry = d.ensure_entry!
          entry.postpone unless entry.postponed?
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
