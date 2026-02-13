class AdozioniAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids
    @analytics = AdozioniAnalytics.new(account: Current.account, scuola_ids: scuola_ids)
    @tab = params[:tab].presence || "mie"
    @filtri = {
      disciplina: params[:disciplina],
      anno_corso: params[:anno_corso],
      editore: params[:editore]
    }.compact_blank

    # For provincia tab
    @provincia = Current.account.scuole.pick(:provincia) || "BO"

    # Filter options for dropdowns
    @discipline = @analytics.discipline_options
    @editori = @analytics.editori_options
  end
end
