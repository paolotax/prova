class ControlloAdozioniController < ApplicationController
  before_action :authenticate_user!

  def index
    @q = params[:q].to_s.strip
    scope = ControlloAnomalia.classifica
    scope = if @q.present?
      scope.where("codicescuola ILIKE :q OR denominazione ILIKE :q OR comune ILIKE :q OR provincia ILIKE :q",
                  q: "%#{@q}%")
    else
      scope.where(codicescuola: codici_account)
    end
    scope = scope.where(provincia: params[:provincia]) if params[:provincia].present?
    @scuole = scope.limit(200)
  end

  def show
    @codicescuola = params[:codicescuola]
    @anomalie = ControlloAnomalia.per_scuola(@codicescuola)
    @per_tipo = @anomalie.group(:tipo).count
    @per_classe = @anomalie.where.not(annocorso: nil)
                           .group_by { |a| [a.annocorso, a.sezioneanno, a.combinazione] }
    @scuola_mancante = @anomalie.per_tipo("scuola_mancante").exists?
    @denominazione = @anomalie.where.not(denominazione: nil).first&.denominazione
  end

  private

  def codici_account
    scuole = Current.account.scuole.where.not(codice_ministeriale: [nil, ""])
    scuole = scuole.where(id: Current.membership.scuola_ids) if Current.membership && !Current.admin?
    scuole.pluck(:codice_ministeriale)
  end
end
