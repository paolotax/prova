# POST controllo_adozioni/cambi_codice — applica in blocco i cambi codice con
# predecessore certo (match), opzionalmente di una sola provincia.
class ControlloAdozioni::CambiCodiceController < ControlloAdozioni::BaseController
  def create
    AggiornaCambiCodiceJob.perform_later(Current.account, provincia: provincia)
    redirect_al_controllo notice: "Aggiornamento dei cambi codice con predecessore avviato."
  end
end
