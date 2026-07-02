class ControlloAdozioniController < ApplicationController
  before_action :authenticate_user!

  def index
    @filtro = params[:filtro].presence
    @panoramica = ControlloAdozioni::Panoramica.new(account: Current.account, scuole: Current.scuole)

    # Pagina i capogruppo (come scuole#index): ogni record e' un gruppo direzione.
    gruppi = @panoramica.gruppi_filtrati(@filtro)
    @total_count = gruppi.sum { |g| g[:scuole].size }
    @gruppi_per_leader = gruppi.index_by { |g| (g[:direzione] || g[:scuole].first).id }

    leader_ids = @gruppi_per_leader.keys
    set_page_and_extract_portion_from Current.scuole.where(id: leader_ids).in_order_of(:id, leader_ids)
  end

  # Promuove in blocco tutte le scuole promuovibili dell'account (fan-out per scuola).
  def promuovi_tutte
    return head(:forbidden) unless Current.admin?

    PromuoviScuolePromuovibiliJob.perform_later(Current.account)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                notice: "Promozione delle scuole promuovibili avviata."
  end

  # Applica in blocco tutti i cambi codice con predecessore suggerito (fan-out per scuola).
  def aggiorna_cambi_codice
    return head(:forbidden) unless Current.admin?

    AggiornaCambiCodiceJob.perform_later(Current.account)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                notice: "Aggiornamento dei cambi codice con predecessore avviato."
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
end
