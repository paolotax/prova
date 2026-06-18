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
    @libri_per_classe = libri_per_classe
  end

  private

  # Tutti i libri da acquistare (EE) della scuola, raggruppati per classe come @per_classe.
  # Serve a dettagliare i libri+prezzi sotto le classi con anomalie. Alternativa alla
  # religione e parascolastica restano visibili ma escluse dal totale spesa
  # (vedi NewAdozione#escluso_dal_tetto?).
  def libri_per_classe
    NewAdozione
      .where(codicescuola: @codicescuola, tipogradoscuola: "EE")
      .where("coalesce(daacquist, '') ILIKE 'S%'")
      .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
      .group_by { |na| [na.annocorso, na.sezioneanno, na.combinazione] }
  end

  def codici_account
    scuole = Current.account.scuole.where.not(codice_ministeriale: [nil, ""])
    scuole = scuole.where(id: Current.membership.scuola_ids) if Current.membership && !Current.admin?
    scuole.pluck(:codice_ministeriale)
  end
end
