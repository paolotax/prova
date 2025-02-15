module Tappe
  class GiroBulkActionsController < ApplicationController
    before_action :authenticate_user!

    def create
      @giro = Giro.find(params[:giro_id])
      @data = Date.parse(params[:data])
      
      @tappe = params[:tappable_ids].map do |tappable_id|
        Tappa.new(
          giro: @giro,
          tappable_type: "ImportScuola",
          tappable_id: tappable_id,
          data_tappa: @data,
          user: current_user
        )
      end
      
      if @tappe.all?(&:save)
        redirect_to @giro, notice: "Tappe create con successo"
      else
        redirect_to @giro, alert: "Errore nella creazione delle tappe"
      end
    end

    private

    def bulk_action_params
      params.permit(:data, :giro_id, tappable_ids: [])
    end
  end
end 