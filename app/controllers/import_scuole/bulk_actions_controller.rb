class ImportScuole::BulkActionsController < ApplicationController

  before_action :authenticate_user!

  def print_all
    @import_scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
    respond_to do |format|
      format.pdf do
        pdf = FoglioScuolaPdf.new(@import_scuole, view_context)
        send_data pdf.render,
          filename: "fogli_scuola_#{Time.current.to_i}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def create_tappa
    @import_scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
    
    import_scuole_ids = @import_scuole.map(&:id).uniq

    import_scuole_ids.each do |import_scuola_id|
      unless import_scuola_id.blank?
        current_user.tappe.find_or_create_by(
          tappable_type: "ImportScuola", 
          tappable_id: import_scuola_id, 
          data_tappa: params[:data_tappa], 
          user_id: current_user.id,
          titolo: params[:titolo],
          giro_id: params[:giro_id]
        )
      end
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "#{helpers.pluralize(import_scuole_ids.size, "tappa aggiunta", "tappe aggiunte")}."
      end
    end
  end

  private

  def bulk_action_params
    params.require(:bulk_action).permit(:data_tappa, :giro_id, :titolo, import_scuola_ids: [])
  end
end
