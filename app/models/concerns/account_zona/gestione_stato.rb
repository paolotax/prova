module AccountZona::GestioneStato
  extend ActiveSupport::Concern

  # Gestisce la rimozione con stato transitorio:
  # - pronta/conteggio → destroy immediato
  # - da_rimuovere → ripristina ad attiva
  # - attiva → marca da_rimuovere
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
