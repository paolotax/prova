class ControlloAdozioniController < ApplicationController
  before_action :authenticate_user!

  # Oltre questo numero di scuole nello scope la lista completa non si carica in
  # landing: la tabella per provincia fa da navigatore e la lista appare sul drill
  # di provincia. Sotto soglia carico tutte le righe, cosi' i filtri client-side
  # (stato/provincia/grado/ricerca) agiscono sull'intero insieme, non su una pagina.
  SOGLIA_LISTA = 1500

  # Pagina unica: riepilogo (card) + passaggio anno + [2+ province] tabella per
  # provincia + lista scuole. Gli aggregati (Dashboard) sono SQL leggeri e si
  # calcolano sempre per l'admin; la Panoramica (pesante) solo quando la lista e'
  # visibile. Adattivo: scope piccolo => lista intera; scope grande => solo drill.
  def index
    @filtro = params[:filtro].presence
    @provincia = params[:provincia].presence

    if Current.admin?
      @dashboard = ControlloAdozioni::Dashboard.new(account: Current.account)
      @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account, provincia: @provincia)
      @province_count = @dashboard.righe.size
    end

    scuole = Current.scuole
    scuole = scuole.where(provincia: @provincia) if @provincia
    @scope_count = scuole.count

    # La lista compare per i member (scope = sue scuole), sui drill espliciti
    # (provincia/filtro) o quando lo scope e' abbastanza piccolo da caricarla tutta.
    @lista_visibile = !Current.admin? || @provincia.present? || @filtro.present? ||
                      @scope_count <= SOGLIA_LISTA
    return unless @lista_visibile

    @panoramica = ControlloAdozioni::Panoramica.new(account: Current.account, scuole: scuole,
                                                    provincia: @provincia)

    # Un record per capogruppo (gruppo direzione), ordinati come scuole#index.
    gruppi = @panoramica.gruppi_filtrati(@filtro)
    @gruppi_per_leader = gruppi.index_by { |g| (g[:direzione] || g[:scuole].first).id }
    leader_ids = @gruppi_per_leader.keys
    ordered = Current.scuole.where(id: leader_ids).in_order_of(:id, leader_ids)

    # Paginazione solo come rete di sicurezza sugli scope grandi (drill di una
    # provincia molto popolosa, o filtro account-wide di un editore): sotto soglia
    # rendo tutte le righe cosi' i filtri client-side sono completi.
    @paginata = @scope_count > SOGLIA_LISTA
    if @paginata
      set_page_and_extract_portion_from ordered
    else
      @leaders = ordered.to_a
    end
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

  # Anteprima delle adozioni MIUR per classe, nel formato del PDF ufficiale
  # "Elenco dei libri di testo adottati o consigliati". Parametrizzata per anno
  # scolastico (?anno=202627); default all'anno corrente pubblicato dal MIUR.
  def anteprima
    @anteprima = ControlloAdozioni::Anteprima.new(codicescuola: params[:codicescuola],
                                                  anno: params[:anno].presence || Miur.anno_corrente)
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
  # (vedi Miur::Adozione#escluso_dal_tetto?).
  def libri_per_classe
    Miur::Adozione
      .per_anno(Miur.anno_corrente)
      .where(codicescuola: @codicescuola, tipogradoscuola: "EE")
      .where("coalesce(daacquist, '') ILIKE 'S%'")
      .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
      .group_by { |na| [na.annocorso, na.sezioneanno, na.combinazione] }
  end
end
