module Tappe
  class BulkActionsController < ApplicationController

    def create
      @tappe = []
      tappable_ids = []
      tappable_type = params[:tappable_type]

      case tappable_type
      when "ImportScuola"
        tappable_ids = current_user.import_scuole.where(id: params[:tappable_ids]).pluck(:id)
      when "Cliente"
        tappable_ids = current_user.clienti.where(id: params[:tappable_ids]).pluck(:id)
      end

      tappable_ids.uniq.each do |tappable_id|
        unless tappable_id.blank?
          tappa = current_user.tappe.find_or_create_by(
            tappable_type: tappable_type,
            tappable_id: tappable_id,
            data_tappa: params[:data_tappa],
            giro_id: params[:giro_id],
            titolo: params[:titolo],
            user_id: current_user.id
          )
          @tappe << tappa
        end
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("giorno-#{params[:data_tappa]}", 
            partial: "tappe/tappa", 
            collection: @tappe, 
            as: :tappa,
            locals: { with_checkbox: false }
          )
        end
      end
    end
    
    private

    def bulk_action_params
      params.require(:bulk_action).permit(:data_tappa, :giro_id, :titolo, :tappable_type, tappable_ids: [])
    end
  end
end