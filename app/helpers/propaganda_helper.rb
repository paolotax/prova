module PropagandaHelper
  # Icona + colore per l'esito di una riga dell'andamento.
  def propaganda_riga_esito(riga)
    if riga.da_ritirare?
      { icon: "☐", label: "da ritirare", color: "oklch(0.5 0.14 50)" }
    elsif riga.rientrata?
      { icon: "✓", label: "rientrato", color: "oklch(0.55 0.02 250)" }
    elsif riga.mancante?
      { icon: "⚠", label: "mancante", color: "oklch(0.5 0.2 25)" }
    else
      { icon: "•", label: riga.esito.to_s.humanize.downcase, color: "oklch(0.55 0.06 160)" }
    end
  end

  # Stile del riepilogo collana: ambra se resta da ritirare, grigio se completata.
  def propaganda_collana_style(collana)
    base = "padding: 0.3rem 0.5rem; list-style: none;"
    colors = if collana.completata?
      "background: oklch(0.96 0.006 250); color: oklch(0.5 0.02 250);"
    else
      "background: oklch(0.94 0.07 70); color: oklch(0.42 0.13 55);"
    end
    "#{colors} #{base}"
  end
end
