class AdozioniAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids
    @analytics = AdozioniAnalytics.new(account: Current.account, scuola_ids: scuola_ids)
    @tab = params[:tab].presence || "mie"
    @filtri = {
      disciplina: params[:disciplina],
      anno_corso: params[:anno_corso],
      editore: params[:editore],
      gruppo: params[:gruppo],
      provincia: params[:provincia],
      grado: params[:grado]
    }.compact_blank

    # For provincia tab
    @provincia = Current.account.scuole.pick(:provincia) || "BO"

    # Filter options scoped to current tab context
    if @tab == "mie"
      opts = @analytics.mie_filter_options
      @discipline = opts[:discipline]
      @editori = opts[:editori]
      @gruppi = opts[:gruppi]
      @province = opts[:province]
      @gradi = opts[:gradi]
    else
      @discipline = @analytics.discipline_options
      @editori = @analytics.editori_options
    end
  end
end
