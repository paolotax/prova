class ImportScuole::BulkActionsController < ApplicationController

  before_action :authenticate_user!

  def print_all
    @import_scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
    respond_to do |format|
      format.pdf do
        tipo_stampa = params[:tipo_stampa] || 'tutte_adozioni'
        con_sovrapacchi = params[:con_sovrapacchi] == 'true'
        pdf = FoglioScuolaPdf.new(@import_scuole, view: view_context, tipo_stampa: tipo_stampa, con_sovrapacchi: con_sovrapacchi)
        
        filename_suffix = tipo_stampa == 'mie_adozioni' ? '_mie_adozioni' : ''
        sovrapacchi_suffix = con_sovrapacchi ? '_con_sovrapacchi' : ''
        filename = "fs#{filename_suffix}#{sovrapacchi_suffix}_#{Time.current.to_i}.pdf"
        
        send_data pdf.render,
          filename: filename,
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def create_tappa

    if params[:import_scuola_ids].present?
      @import_scuole = current_user.import_scuole.where(id: params[:import_scuola_ids])
    end
    if params[:documento_ids].present?
      @documenti = current_user.documenti.where(id: params[:documento_ids])
      @import_scuole = @documenti.map(&:clientable).uniq
    end

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
    params.require(:bulk_action).permit(:data_tappa, :giro_id, :titolo, import_scuola_ids: [], documento_ids: [])
  end
end
