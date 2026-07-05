class ControlloAdozioniController < ApplicationController
  before_action :authenticate_user!

  # Admin senza provincia: dashboard di soli aggregati (niente lista scuole).
  # Member, o admin in drill-down su una provincia: vista operativa (Panoramica).
  def index
    @filtro = params[:filtro].presence
    @provincia = params[:provincia].presence

    # Admin con un filtro attivo (link dalle card) e senza provincia: lista scuole
    # account-wide, non la dashboard.
    if Current.admin? && @provincia.blank? && @filtro.blank?
      @dashboard = ControlloAdozioni::Dashboard.new(account: Current.account)
      @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account)
      return render :dashboard
    end

    @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account, provincia: @provincia) if Current.admin?

    scuole = Current.scuole
    scuole = scuole.where(provincia: @provincia) if @provincia
    @panoramica = ControlloAdozioni::Panoramica.new(account: Current.account, scuole: scuole,
                                                    provincia: @provincia)

    # Pagina i capogruppo (come scuole#index): ogni record e' un gruppo direzione.
    gruppi = @panoramica.gruppi_filtrati(@filtro)
    @total_count = gruppi.sum { |g| g[:scuole].size }
    @gruppi_per_leader = gruppi.index_by { |g| (g[:direzione] || g[:scuole].first).id }

    leader_ids = @gruppi_per_leader.keys
    set_page_and_extract_portion_from Current.scuole.where(id: leader_ids).in_order_of(:id, leader_ids)
  end

  # Promuove in blocco le scuole promuovibili dell'account, opzionalmente di una sola
  # provincia (drill-down admin). Fan-out per scuola.
  def promuovi_tutte
    return head(:forbidden) unless Current.admin?

    provincia = params[:provincia].presence
    PromuoviScuolePromuovibiliJob.perform_later(Current.account, provincia: provincia)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id], provincia: provincia),
                notice: "Promozione delle scuole promuovibili avviata."
  end

  # Applica in blocco i cambi codice con predecessore suggerito, opzionalmente di una
  # sola provincia (drill-down admin). Fan-out per scuola.
  def aggiorna_cambi_codice
    return head(:forbidden) unless Current.admin?

    provincia = params[:provincia].presence
    AggiornaCambiCodiceJob.perform_later(Current.account, provincia: provincia)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id], provincia: provincia),
                notice: "Aggiornamento dei cambi codice con predecessore avviato."
  end

  # Aggiunge in blocco all'anagrafe le "nuove scuole" (codici nuovi senza candidati),
  # opzionalmente di una sola provincia (drill-down admin).
  def aggiungi_scuole_nuove
    return head(:forbidden) unless Current.admin?

    provincia = params[:provincia].presence
    AggiungiScuoleNuoveJob.perform_later(Current.account, provincia: provincia)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id], provincia: provincia),
                notice: "Aggiunta delle nuove scuole avviata."
  end

  # Ricostruisce da zero controllo_anomalie (tabella globale) dallo snapshot MIUR corrente.
  def ricalcola_anomalie
    return head(:forbidden) unless Current.admin?

    RicalcolaAnomalieJob.perform_later
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                notice: "Ricalcolo delle anomalie avviato."
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
