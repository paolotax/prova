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
      scuole = ImportScuola.where(id: params[:import_scuola_ids])
      scuole.each do |scuola|
        scuola.tappe.create(data_tappa: Date.tomorrow, titolo: "Tappa di oggi")
      end
      redirect_to appunti_path, notice: "Tappa aggiunta per domani"
    end

    def add_tappa_custom
      scuole = ImportScuola.where(id: params[:import_scuola_ids])
      custom_date = params[:data]
      scuole.each do |scuola|
        scuola.tappe.create(data: custom_date, titolo: "Tappa personalizzata")
      end
      redirect_to scuole_path, notice: "Tappa personalizzata aggiunta"
    end

    private

    def bulk_action_params
      params.require(:bulk_action).permit(:attribute1, :attribute2, appunto_ids: [])
    end
  end
end