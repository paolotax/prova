module Documenti
  class BulkGestioneController < ApplicationController
    include Documenti::BulkResolvable

    def show
      @documenti = bulk_documenti
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
