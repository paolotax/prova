module Tappe
  class GiroBulkActionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_giro

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
        flash[:notice] = "Tappe create con successo"
        redirect_to @giro, notice: "Tappe create con successo"
      else
        redirect_to @giro, alert: "Errore nella creazione delle tappe"
      end
    end

    def remove_tappa
      @tappa = current_user.tappe.find(params[:tappa_id])
      
      if @tappa.destroy
        redirect_back(fallback_location: @giro, notice: "Tappa rimossa con successo")
      else
        redirect_back(fallback_location: @giro, alert: "Impossibile rimuovere la tappa")
      end
    end

    private

    def set_giro
      @giro = current_user.giri.find(params[:id])
    end

    def bulk_action_params
      params.permit(:data, :giro_id, tappable_ids: [])
    end
  end
end 