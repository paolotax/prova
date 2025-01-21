module ImportScuole
  class BulkActionsController < ApplicationController

    def add_tappa_oggi
      scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
      scuole.each do |scuola|
        scuola.tappe.find_or_create_by(data_tappa: Date.today, titolo: "Tappa di oggi", user_id: current_user.id)
      end

      redirect_to import_scuole_path, notice: "Tappa aggiunta per oggi"
    end
    
    def add_tappa_domani
      scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
      scuole.each do |scuola|
        scuola.tappe.find_or_create_by(data_tappa: Date.tomorrow, titolo: "Tappa di domani", user_id: current_user.id)
      end
      redirect_to import_scuole_path, notice: "Tappa aggiunta per domani"
    end

    def add_tappa_custom
      scuole = ImportScuola.where(id: params[:import_scuola_ids])
      custom_date = params[:data]
      scuole.each do |scuola|
        scuola.tappe.create(data: custom_date, titolo: "Tappa personalizzata", user_id: current_user.id)
      end
      redirect_to scuole_path, notice: "Tappa personalizzata aggiunta"
    end

    private

    def bulk_action_params
      params.require(:bulk_action).permit(:attribute1, :attribute2, import_scuola_ids: [])
    end
  end
end