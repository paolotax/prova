# frozen_string_literal: true

module Documenti
  class BulkConsegneController < ApplicationController
    # POST /documenti/bulk_consegne
    def create
      @documenti = current_account.documenti.where(id: params[:ids])
      consegnato_il = parsed_date(:consegnato_il)

      @documenti.each do |documento|
        if documento.consegna.present?
          # Aggiorna il record esistente
          documento.consegna.update!(consegnato_il: consegnato_il)
        else
          # Crea nuovo record di stato (usa il concern)
          documento.create_consegna!(
            user: Current.user,
            consegnato_il: consegnato_il,
            account: current_account
          )
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to documenti_path, notice: "#{@documenti.count} documenti segnati come consegnati" }
      end
    end

    # DELETE /documenti/bulk_consegne
    def destroy
      @documenti = current_account.documenti.where(id: params[:ids])

      @documenti.each do |documento|
        documento.unmark_consegnato
      end

      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to documenti_path, notice: "#{@documenti.count} documenti: consegna rimossa" }
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
