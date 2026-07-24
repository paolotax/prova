# Broadcast condiviso dei job di promozione (classica e cieca): dopo aver
# promosso una scuola aggiorna via stream la sua riga nella lista di
# controllo_adozioni e rinfresca gli aggregati (step, card riepilogo, tabella
# province). Estratto da ScuolaPromuoviClassiJob per la parita' col gemello cieco.
module BroadcastsControlloRiga
  extend ActiveSupport::Concern

  private

  # Il target dom_id(scuola, :controllo) e' la riga stato-centrica di _riga; i
  # counter cache sono aggiornati async, quindi la Panoramica ricalcola live.
  #
  # Poi rinfresca gli aggregati server-rendered: si aggiornano solo con un
  # morph-refresh sul canale a cui la pagina si iscrive. Messaggi minuscoli
  # (nessuna Panoramica ricostruita qui), che Turbo lato client coalizza.
  def broadcast_riga_controllo(scuola)
    account = scuola.account

    scoped = ControlloAdozioni::Panoramica.new(account: account, scuole: account.scuole.where(id: scuola.id))
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "controllo_adozioni"],
      target: ActionView::RecordIdentifier.dom_id(scuola, :controllo),
      partial: "controllo_adozioni/riga",
      locals: { riga: scoped.riga(scuola.reload, live: true) }
    )

    # Scoped per vista: il drill su una provincia riceve solo la sua, la vista
    # "tutte" riceve "_all". La provincia scuola combacia col param di drill.
    [scuola.provincia.presence, "_all"].compact.uniq.each do |scope|
      Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_riepilogo", scope)
    end
  end
end
