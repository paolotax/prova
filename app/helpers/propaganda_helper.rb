module PropagandaHelper
  # Icona + colore per l'esito di una riga dell'andamento.
  def propaganda_riga_esito(riga)
    if riga.da_ritirare?
      { icon: "☐", label: "da ritirare", color: "var(--color-card-6)" }
    elsif riga.rientrata?
      { icon: "✓", label: "rientrato", color: "oklch(0.55 0.02 250)" }
    elsif riga.mancante?
      { icon: "⚠", label: "mancante", color: "oklch(0.5 0.2 25)" }
    else
      { icon: "•", label: riga.esito.to_s.humanize.downcase, color: "oklch(0.55 0.06 160)" }
    end
  end

  # Colore card + etichetta di stato per una scuola dell'andamento:
  #   completata → grigio   · da_avviare → rosso (mai ritirata)
  #   parziale   → ambra (ritiro avviato ma non finito)
  def propaganda_scuola_stato(cs)
    if cs.completata?
      { color: "var(--color-card-1)", label: "✓ completata" }
    elsif cs.da_avviare?
      { color: "var(--color-card-5)", label: "da ritirare · #{cs.da_ritirare}" }
    else
      { color: "var(--color-card-8)", label: "parziale · #{cs.da_ritirare} mancante" }
    end
  end

  # Stile del riepilogo collana: eredita il colore della card scuola
  # (--card-color), più tenue se completata, più carico se resta da ritirare.
  def propaganda_collana_style(collana)
    base = "padding: 0.3rem 0.5rem; list-style: none;"
    colors = if collana.completata?
      "background: color-mix(in srgb, var(--card-color) 8%, var(--color-canvas)); color: color-mix(in srgb, var(--card-color) 35%, var(--color-ink));"
    else
      "background: color-mix(in srgb, var(--card-color) 20%, var(--color-canvas)); color: color-mix(in srgb, var(--card-color) 50%, var(--color-ink));"
    end
    "#{colors} #{base}"
  end
end
