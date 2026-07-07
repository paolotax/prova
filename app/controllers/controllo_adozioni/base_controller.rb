# Base delle risorse admin del controllo adozioni (azioni massive stile Fizzy:
# ogni operazione e' la create di una risorsa). Guard admin condivisa; provincia
# opzionale per il drill-down; redirect alla pagina controllo con notice.
class ControlloAdozioni::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  private

  def ensure_admin
    head :forbidden unless Current.admin?
  end

  def provincia
    params[:provincia].presence
  end

  def redirect_al_controllo(notice:)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id], provincia: provincia),
                notice: notice
  end
end
