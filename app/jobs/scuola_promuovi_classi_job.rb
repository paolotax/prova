class ScuolaPromuoviClassiJob < ApplicationJob
  queue_as :default

  def perform(scuola, da:, a:, spostamenti_insegnanti: {})
    scuola.promuovi_primaria!(da: da, a: a, spostamenti_insegnanti: spostamenti_insegnanti)
    broadcast_riga_controllo(scuola)
  end

  private

  # Aggiorna controllo_adozioni via stream dopo la promozione:
  #  - la riga della scuola (conteggi live: i counter cache sono aggiornati async);
  #  - le regioni riepilogo account-wide (bottone "Promuovi tutte", filtri, cambi codice),
  #    così i contatori calano/salgono e la card cambio-codice sparisce quando risolta.
  def broadcast_riga_controllo(scuola)
    account = scuola.account
    stream  = [account, "controllo_adozioni"]

    scoped = ControlloAdozioni::Panoramica.new(account: account, scuole: account.scuole.where(id: scuola.id))
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: ActionView::RecordIdentifier.dom_id(scuola, :controllo),
      partial: "controllo_adozioni/riga",
      locals: { riga: scoped.riga(scuola.reload, live: true) }
    )

    full = ControlloAdozioni::Panoramica.new(account: account)
    {
      "controllo_adozioni_promuovi_tutte" => "controllo_adozioni/promuovi_tutte",
      "controllo_adozioni_filtri"         => "controllo_adozioni/filtri",
      "controllo_adozioni_cambi"          => "controllo_adozioni/cambi_codice"
    }.each do |target, partial|
      Turbo::StreamsChannel.broadcast_replace_to(
        stream, target: target, partial: partial,
        locals: { panoramica: full, account_id: account.id }
      )
    end
  end
end
