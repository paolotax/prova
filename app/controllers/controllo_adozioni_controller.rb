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
    @provincia = params[:provincia].presence

    if Current.admin?
      @dashboard = ControlloAdozioni::Dashboard.new(account: Current.account)
      @passaggio = ControlloAdozioni::PassaggioAnno.new(account: Current.account, provincia: @provincia)
      @province_count = @dashboard.righe.size
    end

    scuole = Current.scuole
    scuole = scuole.where(provincia: @provincia) if @provincia
    @scope_count = scuole.count

    # La lista compare per i member (scope = sue scuole), sul drill di provincia o quando
    # lo scope e' abbastanza piccolo da caricarla tutta. Il filtro card/step e' client-side:
    # la lista si carica intera (province-scoped) e le card/step la filtrano nel browser.
    @lista_visibile = !Current.admin? || @provincia.present? || @scope_count <= SOGLIA_LISTA
    return unless @lista_visibile

    @panoramica = ControlloAdozioni::Panoramica.new(account: Current.account, scuole: scuole,
                                                    provincia: @provincia)

    # Un record per capogruppo (gruppo direzione), ordinati come scuole#index.
    gruppi = @panoramica.gruppi
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

  # Anteprima delle adozioni MIUR per classe, nel formato del PDF ufficiale
  # "Elenco dei libri di testo adottati o consigliati". Parametrizzata per anno
  # scolastico (?anno=202627); default all'anno corrente pubblicato dal MIUR.
  def anteprima
    @anteprima = ControlloAdozioni::Anteprima.new(codicescuola: params[:codicescuola],
                                                  anno: params[:anno].presence || Miur.anno_corrente)
  end

  def show
    @scheda = ControlloAdozioni::Scheda.new(account: Current.account,
                                            codicescuola: params[:codicescuola])
  end
end
