class ScuolaPromuoviClassiJob < ApplicationJob
  # :bulk — è il figlio del fan-out delle promozioni di massa (migliaia). Tenuto fuori
  # dalla coda :default per non bloccare i job interattivi (broadcast, azioni utente).
  queue_as :bulk

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
    broadcast_riga_controllo(scuola)
  end

  private

  # Aggiorna via stream la riga della scuola nella lista di controllo_adozioni dopo la
  # promozione (conteggi live: i counter cache sono aggiornati async). Il target
  # dom_id(scuola, :controllo) è la riga stato-centrica di _riga.
  #
  # NB: gli aggregati (card riepilogo, step, tabella province) NON si aggiornano
  # per-scuola: nel fan-out di massa sarebbe O(scuole) ricostruzioni pesanti. Si
  # rinfrescano al reload della pagina (scelta coerente con il merge dashboard/index).
  def broadcast_riga_controllo(scuola)
    account = scuola.account

    scoped = ControlloAdozioni::Panoramica.new(account: account, scuole: account.scuole.where(id: scuola.id))
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "controllo_adozioni"],
      target: ActionView::RecordIdentifier.dom_id(scuola, :controllo),
      partial: "controllo_adozioni/riga",
      locals: { riga: scoped.riga(scuola.reload, live: true) }
    )
  end
end
