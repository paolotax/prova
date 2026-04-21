class AdozioniAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids
    @analytics = AdozioniAnalytics.new(account: Current.account, scuola_ids: scuola_ids)
    @filtri = {
      disciplina: params[:disciplina],
      anno_corso: params[:anno_corso],
      editore: params[:editore],
      gruppo: params[:gruppo],
      provincia: params[:provincia],
      grado: params[:grado],
      tipo_scuola: params[:tipo_scuola],
      area: params[:area],
      adozioni_tipo: params[:adozioni_tipo].presence
    }.compact_blank

    opts = @analytics.mie_filter_options(filtri: @filtri)
    @discipline  = opts[:discipline]
    @editori     = opts[:editori]
    @gruppi      = opts[:gruppi]
    @province    = opts[:province]
    @gradi       = opts[:gradi]
    @tipi_scuola = opts[:tipi_scuola]
    @aree        = opts[:aree]
    @anni_corso  = opts[:anni_corso]

    @rows = @analytics.mie_adozioni(filtri: @filtri).to_a
    scuole_scope = Current.account.scuole.where(id: scuola_ids)
                          .where.not(codice_ministeriale: [nil, ""])
    scuole_scope = scuole_scope.where(provincia: @filtri[:provincia])     if @filtri[:provincia].present?
    scuole_scope = scuole_scope.where(grado: @filtri[:grado])             if @filtri[:grado].present?
    scuole_scope = scuole_scope.where(tipo_scuola: @filtri[:tipo_scuola]) if @filtri[:tipo_scuola].present?
    scuole_scope = scuole_scope.where(area: @filtri[:area])               if @filtri[:area].present?
    codici_ministeriali = scuole_scope.pluck(:codice_ministeriale)

    @zone_totals     = @analytics.zone_market_totals(@rows, codici_ministeriali: codici_ministeriali)
    @national_book   = @analytics.national_book_shares(@rows)
    @national_totals = @analytics.national_market_totals(@rows)
  end
end
