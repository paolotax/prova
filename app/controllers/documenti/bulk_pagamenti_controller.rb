module Documenti
  class BulkPagamentiController < ApplicationController
    before_action :load_documenti

    def create
      pagato_il = Date.parse(params[:pagato_il]) rescue Date.today
      tipo_pagamento = params[:tipo_pagamento].presence

      @documenti.each do |documento|
        next if documento.pagato?
        documento.mark_pagato(pagato_il: pagato_il, tipo_pagamento: tipo_pagamento)
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
      @documenti = current_account.documenti
        .where(id: params[:ids])
        .includes(:causale, :consegna, :pagamento, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end

    def reload_documenti
      @documenti = current_account.documenti
        .where(id: params[:ids])
        .includes(:causale, :consegna, :pagamento, :clientable, :righe, :entry)
      @documenti_per_cliente = @documenti.group_by(&:clientable)
    end
  end
end
