module Documenti
  class BulkGestioneController < ApplicationController
    def show
      @documenti = current_account.documenti
        .where(id: params[:ids])
        .includes(:causale, :consegna, :pagamento, :clientable, :righe)
        .order(:clientable_type, :clientable_id, :data_documento)

      @documenti_per_cliente = @documenti.group_by(&:clientable)

      respond_to do |format|
        format.turbo_stream
        format.html { render layout: false }
      end
    end
  end
end
