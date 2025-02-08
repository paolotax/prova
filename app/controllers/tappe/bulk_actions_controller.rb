module Tappe
  class BulkActionsController < ApplicationController

    before_action :authenticate_user!

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
    
    def update_all  
      tappa_ids   = params.fetch(:tappa_ids, []).compact
      new_data_tappa = params[:data_tappa]
      new_titolo     = params[:titolo]
      new_giro_id    = params[:giro_id]
      
      @selected_tappe = current_user.tappe.where(id: tappa_ids)
    
      @selected_tappe.each do |tappa|
        tappa.update(
          data_tappa: new_data_tappa,
          titolo: new_titolo,
          giro_id: new_giro_id
        )
      end
      
      flash[:notice] = "#{@selected_tappe.count} tappe aggiornate"     
      respond_to do |format|
        format.html { redirect_to giorno_path(new_data_tappa) }
        format.turbo_stream { turbo_redirect_to(giorno_path(new_data_tappa)) }
      end
    end

    def destroy_all
      @selected_tappe = current_user.tappe.where(id: params.fetch(:tappa_ids, []).compact)
      giorno = @selected_tappe.first.data_tappa
      count = @selected_tappe.count
      @selected_tappe.destroy_all
      flash[:notice] = helpers.pluralize(count, "tappa eliminata", "tappe eliminate")
      respond_to do |format|
        format.html { redirect_to giorno_path(giorno) }
        format.turbo_stream { turbo_redirect_to(giorno_path(giorno)) }
      end
    end

    private

    def bulk_action_params
      params.permit(:data_tappa, :giro_id, :titolo, :tappable_type, tappable_ids: [])
    end

    def turbo_redirect_to(path)
      render turbo_stream: turbo_stream.append_all("body", 
        "<script>window.location.href = '#{path}';</script>".html_safe
      )
    end
  end
end