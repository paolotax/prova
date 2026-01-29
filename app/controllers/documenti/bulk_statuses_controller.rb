# frozen_string_literal: true

module Documenti
  class BulkStatusesController < ApplicationController
    def update
      @documenti = current_account.documenti.where(id: params[:ids])
      count = @documenti.count

      @documenti.find_each do |documento|
        documento.update(stato_params.compact)
      end

      notice = "Stato aggiornato per #{helpers.pluralize(count, 'documento', 'documenti')}"

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to documenti_path, notice: notice }
      end
    end

    private

    def stato_params
      params.permit(:status, :tipo_pagamento, :pagato_il, :consegnato_il)
    end
  end
end
