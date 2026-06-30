class AdozioniAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids

    # Owner/admin: restringe lo scope alle scuole assegnate a un singolo agente
    if Current.admin?
      @agenti = Current.account.memberships
                       .where(id: Accounts::MembershipScuola.select(:membership_id))
                       .includes(:user)
      membership_scuole = Accounts::MembershipScuola
                            .where(membership_id: Current.account.memberships.select(:id))
                            .where(scuola_id: Current.account.scuole.select(:id))
      @conteggi_agenti = membership_scuole.group(:membership_id).count
      @conteggi_agenti[:none] = Current.account.scuole.count -
                                membership_scuole.distinct.count(:scuola_id)
      if params[:agente_id] == "none"
        @agente = :none
        assegnate_ids = Accounts::MembershipScuola
                          .where(membership_id: Current.account.memberships.select(:id))
                          .select(:scuola_id)
        scuola_ids = Current.account.scuole.where.not(id: assegnate_ids).pluck(:id)
      elsif params[:agente_id].present?
        @agente = @agenti.find_by(id: params[:agente_id])
        scuola_ids = @agente.scuola_ids if @agente
      end
    end

    @analytics = AdozioniAnalytics.new(account: Current.account, scuola_ids: scuola_ids)
    @tab = %w[mie tutte editori].include?(params[:tab]) ? params[:tab] : "mie"
    solo_mie = @tab == "mie"
    @filtri = {
      disciplina: params[:disciplina],
      anno_corso: params[:anno_corso],
      editore: params[:editore],
      gruppo: params[:gruppo],
      regione: params[:regione],
      provincia: params[:provincia],
      grado: params[:grado],
      tipo_scuola: params[:tipo_scuola],
      area: params[:area],
      adozioni_tipo: params[:adozioni_tipo].presence
    }.compact_blank

    opts = @analytics.filter_options(filtri: @filtri, solo_mie: solo_mie)
    @discipline  = opts[:discipline]
    @editori     = opts[:editori]
    @gruppi      = opts[:gruppi]
    @regioni     = opts[:regioni]
    @province    = opts[:province]
    @gradi       = opts[:gradi]
    @tipi_scuola = opts[:tipi_scuola]
    @aree        = opts[:aree]
    @anni_corso  = opts[:anni_corso]

    @rows = @analytics.adozioni(filtri: @filtri, solo_mie: solo_mie).to_a
    scuole_scope = Current.account.scuole.where(id: scuola_ids)
                          .where.not(codice_ministeriale: [nil, ""])
    scuole_scope = scuole_scope.where(regione: @filtri[:regione])         if @filtri[:regione].present?
    scuole_scope = scuole_scope.where(provincia: @filtri[:provincia])     if @filtri[:provincia].present?
    scuole_scope = scuole_scope.where(grado: @filtri[:grado])             if @filtri[:grado].present?
    scuole_scope = scuole_scope.where(tipo_scuola: @filtri[:tipo_scuola]) if @filtri[:tipo_scuola].present?
    scuole_scope = scuole_scope.where(area: @filtri[:area])               if @filtri[:area].present?
    codici_ministeriali = scuole_scope.pluck(:codice_ministeriale)

    @zone_totals     = @analytics.zone_market_totals(@rows, codici_ministeriali: codici_ministeriali)
    @national_book   = @analytics.national_book_shares(@rows)
    @national_totals = @analytics.national_market_totals(@rows)

    respond_to do |format|
      format.html
      format.xlsx { response.headers["Content-Disposition"] = 'attachment; filename="adozioni.xlsx"' }
    end
  end
end
