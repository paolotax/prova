module Appunti
  class BulkActionsController < ApplicationController

    before_action :authenticate_user!

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

    def add_tappa_giorno
      @appunti = current_user.appunti.where(id: params[:appunto_ids])
      
      scuole_ids = @appunti.map(&:import_scuola_id).uniq

      scuole_ids.each do |scuola_id|
        unless scuola_id.blank?
          current_user.tappe.find_or_create_by(tappable_type: "ImportScuola", tappable_id: scuola_id, data_tappa: params[:data_tappa], user_id: current_user.id)
        end
      end

      respond_to do |format|
        format.turbo_stream
      end
    end

    def segna_come
      @appunti = current_user.appunti.where(id: params[:appunto_ids])
      @appunti.update_all(stato: params[:stato])

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: @appunti.map { |appunto|
            turbo_stream.replace("appunto_#{appunto.id}", partial: "appunti/appunto", locals: { appunto: appunto })
          }
        }
      end
    end


    def destroy_all
      @ids = params[:appunto_ids]
      count = @ids.count

      @appunti = current_user.appunti.where(id: @ids)
      @appunti.destroy_all
      flash[:notice] = helpers.pluralize(count, "appunto eliminato", "appunti eliminati")
      respond_to do |format|
        format.html { redirect_to appunti_path }
        format.turbo_stream
      end
    end

    private

    def bulk_action_params
      params.require(:bulk_action).permit(:data_tappa, :status, appunto_ids: [])
    end
  end
end