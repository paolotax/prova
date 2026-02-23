module Accounts::Zona::GestioneStato
  extend ActiveSupport::Concern

  def toggle_rimozione!
    case stato
    when "pronta", "conteggio"
      destroy!
    when "da_rimuovere"
      update!(stato: "attiva")
    else
      update!(stato: "da_rimuovere")
    end
  end
end
