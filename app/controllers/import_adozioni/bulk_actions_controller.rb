class ImportAdozioni::BulkActionsController < ApplicationController

  before_action :authenticate_user!

  def print_all
    Rails.logger.info "=== BULK PRINT ALL CALLED ==="
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "import_adozione_ids: #{params[:import_adozione_ids]}"

    @import_adozioni = current_user.import_adozioni.where(id: params[:import_adozione_ids])

    Rails.logger.info "Found #{@import_adozioni.count} import_adozioni"

    respond_to do |format|
      format.pdf do
        pdf = ImportAdozionePdf.new(@import_adozioni, view_context)
        send_data pdf.render,
          filename: "etichette_#{Time.current.to_i}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  private

  def bulk_action_params
    params.permit(import_adozione_ids: [])
  end
end
