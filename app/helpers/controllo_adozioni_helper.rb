module ControlloAdozioniHelper
  # Variante colore del badge per tipo di anomalia (vedi entries.css: badge--*).
  ANOMALIA_BADGE_COLORE = {
    "tetto_superato"      => "badge--mancante",
    "scuola_mancante"     => "badge--mancante",
    "disciplina_mancante" => "badge--mancante",
    "doppione"            => "badge--yellow",
    "prezzo_isbn"         => "badge--blue",
    "prezzo_disciplina"   => "badge--blue",
  }.freeze

  def anomalia_badge_colore(tipo)
    ANOMALIA_BADGE_COLORE.fetch(tipo, "")
  end
end
