class ScuolaPromuoviClassiJob < ApplicationJob
  # :bulk — è il figlio del fan-out delle promozioni di massa (migliaia). Tenuto fuori
  # dalla coda :default per non bloccare i job interattivi (broadcast, azioni utente).
  queue_as :bulk

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
    broadcast_riga_controllo(scuola)
  end

  private

  RIEPILOGHI = {
    "controllo_adozioni_promuovi_tutte" => "controllo_adozioni/promuovi_tutte",
    "controllo_adozioni_cambi"          => "controllo_adozioni/cambi_codice"
  }.freeze

  # Aggiorna controllo_adozioni via stream dopo la promozione:
  #  - la riga della scuola (conteggi live: i counter cache sono aggiornati async);
  #  - i riepiloghi (bottone "Promuovi tutte", filtri, cambi codice), così i contatori
  #    calano/salgono e la card cambio-codice sparisce quando risolta.
  def broadcast_riga_controllo(scuola)
    account = scuola.account

    scoped = ControlloAdozioni::Panoramica.new(account: account, scuole: account.scuole.where(id: scuola.id))
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "controllo_adozioni"],
      target: ActionView::RecordIdentifier.dom_id(scuola, :controllo),
      partial: "controllo_adozioni/riga",
      locals: { riga: scoped.riga(scuola.reload, live: true) }
    )

    # I riepiloghi sono scoped per vista: il drill-down su una provincia mostra solo quella
    # provincia, la vista "tutte" (membri / admin senza filtro) tutto l'account. Vanno su
    # stream separati per scope, altrimenti la vista provincia verrebbe clobberata con dati
    # account-wide (bug: la lista cambi codice si ripopolava con tutte le province).
    broadcast_riepiloghi(account, provincia: scuola.provincia.presence)
    broadcast_riepiloghi(account, provincia: nil)

    # La dashboard admin (aggregati per provincia) non ha target puntuali: refresh
    # completo via morph. Turbo lato client scarta i refresh mentre uno e' in volo.
    Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_dashboard")
  end

  def broadcast_riepiloghi(account, provincia:)
    scuole = provincia ? account.scuole.where(provincia: provincia) : nil
    panoramica = ControlloAdozioni::Panoramica.new(account: account, scuole: scuole, provincia: provincia)
    stream = [account, "controllo_adozioni_riepilogo", provincia || "_all"]
    RIEPILOGHI.each do |target, partial|
      Turbo::StreamsChannel.broadcast_replace_to(
        stream, target: target, partial: partial,
        locals: { panoramica: panoramica, account_id: account.id, provincia: provincia }
      )
    end
  end
end
