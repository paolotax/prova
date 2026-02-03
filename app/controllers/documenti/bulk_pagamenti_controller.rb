# frozen_string_literal: true

module Documenti
  class BulkPagamentiController < ApplicationController
    # POST /documenti/bulk_pagamenti
    def create
      @documenti = current_account.documenti.where(id: params[:ids])
      pagato_il = parsed_date(:pagato_il)
      tipo_pagamento = params[:tipo_pagamento].presence

      @documenti.each do |documento|
        if documento.pagamento.present?
          # Aggiorna il record esistente
          documento.pagamento.update!(pagato_il: pagato_il, tipo_pagamento: tipo_pagamento)
        else
          # Crea nuovo record di stato (usa il concern)
          documento.create_pagamento!(
            user: Current.user,
            pagato_il: pagato_il,
            tipo_pagamento: tipo_pagamento,
            account: current_account
          )
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "#{@documenti.count} documenti segnati come pagati" }
      end
    end

    # DELETE /documenti/bulk_pagamenti
    def destroy
      @documenti = current_account.documenti.where(id: params[:ids])

      @documenti.each do |documento|
        documento.unmark_pagato
      end

      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to documenti_path, notice: "#{@documenti.count} documenti: pagamento rimosso" }
      end
    end

    private

    def parsed_date(param)
      return Date.today unless params[param].present?
      Date.parse(params[param])
    rescue ArgumentError
      Date.today
    end
  end
end
