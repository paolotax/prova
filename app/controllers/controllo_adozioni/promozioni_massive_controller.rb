# POST controllo_adozioni/promozioni_massive — promuove in blocco le scuole
# promuovibili dell'account, opzionalmente di una sola provincia. Fan-out per scuola.
class ControlloAdozioni::PromozioniMassiveController < ControlloAdozioni::BaseController
  def create
    PromuoviScuolePromuovibiliJob.perform_later(Current.account, provincia: provincia)
    redirect_al_controllo notice: "Promozione delle scuole promuovibili avviata."
  end
end
