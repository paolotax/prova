module Documenti
  class BulkPagamentiController < ApplicationController
    include Documenti::BulkResolvable

    before_action :load_documenti

    # params[:usa_data_documento] opzionale: ogni documento viene pagato
    # nella propria data documento invece che nella data unica indicata
    def create
      usa_data_documento = params[:usa_data_documento].present?
      pagato_il = Date.parse(params[:pagato_il]) rescue Date.today
      tipo_pagamento = params[:tipo_pagamento].presence

      @documenti.each do |documento|
        next if documento.pagato? || !documento.pagamento_applicabile?
        documento.mark_pagato(pagato_il: usa_data_documento ? documento.data_documento : pagato_il,
                              tipo_pagamento: tipo_pagamento)
      end

      reload_documenti

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: documenti_path, notice: "#{@documenti.size} documenti segnati come pagati" }
      end
    end

    def destroy
      @documenti.each(&:unmark_pagato)

      reload_documenti

      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_back fallback_location: documenti_path, notice: "Pagamenti rimossi da #{@documenti.size} documenti" }
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
