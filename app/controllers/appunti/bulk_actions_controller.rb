module Appunti
  class BulkActionsController < ApplicationController

    def print_all
      @appunti = current_user.appunti.where(id: params[:appunto_ids])
      
      respond_to do |format|
        format.pdf do
          pdf = AppuntoPdf.new(@appunti, view_context)
          send_data pdf.render,
            filename: "appunti_#{Time.current.to_i}.pdf",
            type: "application/pdf",
            disposition: "inline"
        end
      end
    end

    def add_tappa_oggi
      scuole_ids = current_user.appunti.where(id: params[:appunto_ids]).map(&:import_scuola_id).uniq

      scuole_ids.each do |scuola_id|
        unless scuola_id.blank?
          current_user.tappe.find_or_create_by(tappable_type: "ImportScuola", tappable_id: scuola_id, data_tappa: Date.today, user_id: current_user.id)
        end
      end

      redirect_to appunti_path, notice: "Tappe aggiunte per oggi"
    end

    def add_tappa_qiorno
      scuole_ids = current_user.appunti.where(id: params[:appunto_ids]).map(&:import_scuola_id).uniq

      scuole_ids.each do |scuola_id|
        unless scuola_id.blank?
          current_user.tappe.find_or_create_by(tappable_type: "ImportScuola", tappable_id: scuola_id, data_tappa: params[:data_tappa], user_id: current_user.id)
        end
      end

      redirect_to appunti_path, notice: "Tappe aggiunte per #{params[:data_tappa]}"
    end



    def segna_come
      @appunti = current_user.appunti.where(id: params[:appunto_ids])
      @appunti.update_all(stato: params[:stato])
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("appunto_#{@appunti.first.id}",  partial: "appunti/appunto",  locals: { appunto: @appunti.first } )
        end
      end
    end

    private

    def bulk_action_params
      params.require(:bulk_action).permit(:data_tappa, :status, appunto_ids: [])
    end
  end
end