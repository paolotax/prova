# POST controllo_adozioni/scuole_nuove — aggiunge all'anagrafe le "nuove scuole"
# (codici nuovi senza candidati): in blocco (per provincia) o la singola scuola
# quando arriva un `codice` (pulsante Aggiungi sulla riga).
class ControlloAdozioni::ScuoleNuoveController < ControlloAdozioni::BaseController
  def create
    if (codice = params[:codice].presence)
      AggiungiScuoleNuoveJob.perform_later(Current.account, provincia: provincia, codici: [codice])
      redirect_al_controllo notice: "Aggiunta della scuola avviata."
    else
      AggiungiScuoleNuoveJob.perform_later(Current.account, provincia: provincia)
      redirect_al_controllo notice: "Aggiunta delle nuove scuole avviata."
    end
  end
end
