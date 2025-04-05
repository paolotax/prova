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

      new_data_tappa = params[:data_tappa]
      new_titolo     = params[:titolo]
      new_giro_ids    = params[:giro_ids]

      tappable_ids.uniq.each do |tappable_id|
        unless tappable_id.blank?
          tappa = current_user.tappe.find_or_create_by(
            tappable_type: tappable_type,
            tappable_id: tappable_id,
            data_tappa: new_data_tappa,
            titolo: new_titolo,
            user_id: current_user.id
          )
          update_tappa_giri(tappa, new_giro_ids) if new_giro_ids.present?
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

  
    def duplica 
      
      @tappe = current_user.tappe.where(id: params[:tappa_ids])
      @tappe_create = []
      
      @tappe.each do |tappa|
        nuova_tappa = tappa.dup
        nuova_tappa.data_tappa = params[:data_tappa]
        nuova_tappa.titolo = params[:titolo]
        nuova_tappa.save

        update_tappa_giri(nuova_tappa, params[:giro_ids]) if params[:giro_ids].present?    
        @tappe_create << nuova_tappa
      end

      flash[:notice] = helpers.pluralize(@tappe_create.count, 'tappa duplicata', 'tappe duplicate')

      respond_to do |format|
        format.turbo_stream { turbo_redirect_to(giorno_path(params[:data_tappa])) }
        format.html { redirect_to giorno_path(params[:data_tappa]) }
      end
    end

    def update_all  
      tappa_ids   = params.fetch(:tappa_ids, []).compact
      
      new_data_tappa = params[:data_tappa]
      # new_titolo     = params[:titolo] unless params[:titolo].nil?
      # new_giro_id    = params[:giro_id] unless params[:giro_id].nil?
      
      @selected_tappe = current_user.tappe.where(id: tappa_ids)
    
      @selected_tappe.each do |tappa|
        tappa.update(bulk_action_params.reject { |_, v| v.nil? || v.blank? }) 
        update_tappa_giri(tappa, params[:giro_ids]) if params[:giro_ids].present?
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

    def update_tappa_giri(tappa, giro_ids)
      return if giro_ids.blank?
      
      # Se giro_ids è già una stringa con virgole, la usiamo così com'è
      # altrimenti la convertiamo in una stringa singola
      giro_ids_string = giro_ids.is_a?(Array) ? giro_ids.join(',') : giro_ids.to_s
      
      # Converte la stringa di ID in un array di interi
      giro_ids_array = giro_ids_string.split(',').map(&:to_i)
      
      # Rimuove tutte le associazioni esistenti e crea quelle nuove
      tappa.tappa_giri.destroy_all
      giro_ids_array.each do |giro_id|
        tappa.tappa_giri.create(giro_id: giro_id)
      end
    end

    def bulk_action_params
      params.permit(:data_tappa, :giro_ids, :titolo, :tappable_type, tappable_ids: [])
    end

    def turbo_redirect_to(path)
      render turbo_stream: turbo_stream.append_all("body", 
        "<script>window.location.href = '#{path}';</script>".html_safe
      )
    end
  end
end