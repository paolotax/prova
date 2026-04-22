module BroadcastsPulsanteAggiornaAdozioni
  extend ActiveSupport::Concern

  private

  def broadcast_pulsante_stato(account)
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "pulsante-aggiorna-adozioni",
      partial: "accounts/configurazione/pulsante_aggiorna_adozioni",
      locals: { account: account.reload }
    )
  end
end
