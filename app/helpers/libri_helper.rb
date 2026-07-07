module LibriHelper
  def libro_color(libro)
    case libro.categoria&.nome_categoria&.downcase
    when "scolastica"          then "oklch(0.6 0.15 250)"  # blue
    when "parascolastica"      then "oklch(0.6 0.15 160)"  # emerald
    when "narrativa"           then "oklch(0.6 0.15 45)"   # amber
    when "universitaria"       then "oklch(0.6 0.15 280)"  # violet
    when "varia"               then "oklch(0.6 0.15 15)"   # rose
    else "oklch(0.6 0.01 0)"  # gray default
    end
  end

  def libro_sconto_color(libro)
    sconto = libro_sconto_percentuale(libro)
    case sconto
    when 0..14      then "oklch(0.55 0.18 25)"   # red - sconto basso
    when 15..19     then "oklch(0.65 0.18 55)"   # orange
    when 20..24     then "oklch(0.75 0.18 85)"   # yellow
    when 25..29     then "oklch(0.65 0.18 145)"  # green
    else                 "oklch(0.55 0.18 160)"  # emerald - sconto alto
    end
  end

  def libro_sconto_percentuale(libro)
    return 0 if libro.prezzo.to_f.zero? || libro.prezzo_suggerito.to_f.zero?
    ((1 - (libro.prezzo_suggerito.to_f / libro.prezzo.to_f)) * 100).round
  end

  def libro_badge_class(libro)
    return "badge--positive" if libro.adozioni_count.positive?
    return "badge--warning" if libro.giacenza&.impegnato.to_i.positive?
    ""
  end

  def libro_adottabile?(libro)
    libro.categoria&.nome_categoria&.downcase == "scolastica"
  end
end
