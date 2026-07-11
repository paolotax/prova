module Documenti
  class BulkConsegneController < ApplicationController
    include Documenti::BulkResolvable

    before_action :load_documenti

    # params[:usa_data_documento] opzionale: ogni documento viene consegnato
    # nella propria data documento invece che nella data unica indicata
    def create
      usa_data_documento = params[:usa_data_documento].present?
      consegnato_il = Date.parse(params[:consegnato_il]) rescue Date.today

      @documenti.each do |documento|
        next if documento.consegnato? || !documento.consegna_applicabile?
        documento.mark_consegnato(consegnato_il: usa_data_documento ? documento.data_documento : consegnato_il)
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
        .includes(:causale, :consegne, :pagamenti, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end

    def reload_documenti
      @documenti = bulk_documenti
        .includes(:causale, :consegne, :pagamenti, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end
  end
end
