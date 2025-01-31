module ImportScuole
  class BulkActionsController < ApplicationController

    def add_tappa_giorno
      @import_scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
      
      import_scuole_ids = @import_scuole.map(&:id).uniq

      import_scuole_ids.each do |import_scuola_id|
        unless import_scuola_id.blank?
          current_user.tappe.find_or_create_by(tappable_type: "ImportScuola", tappable_id: import_scuola_id, data_tappa: params[:data_tappa], user_id: current_user.id)
        end
      end

      respond_to do |format|
        format.turbo_stream
      end
    end
    private

    def bulk_action_params
      params.require(:bulk_action).permit(:data_tappa, import_scuola_ids: [])
    end
  end
end