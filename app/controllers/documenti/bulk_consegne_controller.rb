module Documenti
  class BulkConsegneController < ApplicationController
    include Documenti::BulkResolvable

    before_action :load_documenti

    def create
      consegnato_il = Date.parse(params[:consegnato_il]) rescue Date.today

      @documenti.each do |documento|
        next if documento.consegnato?
        documento.mark_consegnato(consegnato_il: consegnato_il)
      end

      reload_documenti

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: documenti_path, notice: "#{@documenti.size} documenti segnati come consegnati" }
      end
    end

    def destroy
      @documenti.each(&:unmark_consegnato)

      reload_documenti

      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_back fallback_location: documenti_path, notice: "Consegne rimosse da #{@documenti.size} documenti" }
      end
    end

    private

    def load_documenti
      @documenti = bulk_documenti
        .includes(:causale, :consegne, :pagamento, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end

    def reload_documenti
      @documenti = bulk_documenti
        .includes(:causale, :consegne, :pagamento, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end
  end
end
