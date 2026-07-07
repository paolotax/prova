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

  # Stato dominante di una Panoramica::Riga per la lista unificata "stato-centrica".
  # Priorita' (piu' azionabile per prima): promuovi > anomalie > disall > fuori > ok.
  # => { stato:, badge_class:, badge_label:, azione: } (azione = simbolo reso nel partial).
  def stato_riga(riga)
    if riga.promuovibile?
      { stato: "promuovi", badge_class: "badge--green",    badge_label: "Da promuovere",  azione: :promuovi }
    elsif riga.anomalie?
      n = riga.anomalie_count.to_i
      { stato: "anomalie", badge_class: "badge--mancante", badge_label: "#{n} #{n == 1 ? 'anomalia' : 'anomalie'}", azione: :vedi }
    elsif riga.disallineata?
      { stato: "disall",   badge_class: "badge--grey",     badge_label: "Disallineata",   azione: :anteprima }
    elsif riga.mancante_miur?
      { stato: "fuori",    badge_class: "badge--grey",     badge_label: "Non nel MIUR",   azione: :none }
    else
      { stato: "ok",       badge_class: "badge--ok",       badge_label: "A posto",        azione: :none }
    end
  end

  # Stato di una Panoramica::Mancante (cambi codice / nuove scuole).
  def stato_mancante(mancante)
    case mancante.tipo
    when :match
      { stato: "cambio",   badge_class: "badge--blue",   badge_label: "Cambio codice",   azione: :applica }
    when :suggerimento
      { stato: "verifica", badge_class: "badge--yellow", badge_label: "Da verificare",   azione: :scegli }
    else
      { stato: "nuova",    badge_class: "badge--aqua",   badge_label: "Nuova nel MIUR",  azione: :aggiungi }
    end
  end

  # Chiave di stato (data-state / data-step-key) usata dal filtro client-side, derivata
  # dalla key dello Step del PassaggioAnno. rifinitura filtra verifica + anomalie.
  STEP_FILTER_KEY = {
    cambi_codice: "cambio", promuovibili: "promuovi",
    scuole_nuove: "nuova",  rifinitura: "rifinitura"
  }.freeze

  def step_filter_key(step) = STEP_FILTER_KEY.fetch(step.key, step.key.to_s)

  # Grado sintetico (E=primaria, M=media, N=superiore, A=infanzia) per il filtro.
  # Usa il grado della scuola se valido, altrimenti lo deriva dal codice ministeriale
  # (posizioni 3-4: EE/MM/AA, tutto il resto -> superiore).
  def grado_riga(codice, grado = nil)
    return grado if %w[E M N A].include?(grado.to_s)

    case codice.to_s[2, 2].to_s.upcase
    when "EE" then "E"
    when "MM" then "M"
    when "AA" then "A"
    else "N"
    end
  end

  # Provincia estesa (nome affidabile per l'editore) di una scuola/riga, per data-prov.
  def sigla_o_provincia(scuola)
    scuola.sigla_provincia.presence || scuola.provincia
  end
end
