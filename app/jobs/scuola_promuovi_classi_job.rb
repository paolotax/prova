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
  # Poi rinfresca gli aggregati (step, card riepilogo, tabella province): sono
  # server-rendered e si aggiornano solo con un morph-refresh sul canale a cui la
  # pagina si iscrive. Nel fan-out di massa arrivano N refresh, ma sono messaggi
  # minuscoli (nessuna Panoramica ricostruita qui) e Turbo lato client li coalizza
  # in pochi reload — a differenza del vecchio broadcast_riepiloghi, O(scuole) pesante.
  def broadcast_riga_controllo(scuola)
    account = scuola.account

    scoped = ControlloAdozioni::Panoramica.new(account: account, scuole: account.scuole.where(id: scuola.id))
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "controllo_adozioni"],
      target: ActionView::RecordIdentifier.dom_id(scuola, :controllo),
      partial: "controllo_adozioni/riga",
      locals: { riga: scoped.riga(scuola.reload, live: true) }
    )

    # Scoped per vista: il drill su una provincia riceve solo la sua, la vista "tutte"
    # (membri / admin senza filtro) riceve "_all". La provincia scuola combacia col
    # param di drill (scuole.where(provincia:) nel fan-out) — vedi _province#link.
    [scuola.provincia.presence, "_all"].compact.uniq.each do |scope|
      Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_riepilogo", scope)
    end
  end
end
