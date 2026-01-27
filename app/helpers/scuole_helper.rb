module ScuoleHelper
  def scuola_color(scuola)
    case scuola.tipo_scuola&.downcase
    when "istituto comprensivo"      then "oklch(0.6 0.15 250)"  # blue
    when "scuola primaria"           then "oklch(0.6 0.15 160)"  # emerald
    when "scuola secondaria i grado" then "oklch(0.6 0.15 45)"   # amber
    when "liceo scientifico"         then "oklch(0.6 0.15 280)"  # violet
    when "liceo classico"            then "oklch(0.6 0.15 320)"  # pink
    when "liceo linguistico"         then "oklch(0.6 0.15 200)"  # cyan
    when "istituto tecnico"          then "oklch(0.6 0.15 15)"   # rose
    when "istituto professionale"    then "oklch(0.6 0.15 100)"  # lime
    else "oklch(0.6 0.01 0)"  # gray default
    end
  end

  def scuola_badge_class(scuola)
    return "badge--positive" if scuola.classi.any?
    return "badge--warning" if scuola.priorita.to_i > 3
    ""
  end

  def priorita_stars(priorita)
    return "" if priorita.to_i.zero?
    content_tag(:span, class: "flex gap-quarter", style: "color: var(--color-warning);") do
      safe_join(priorita.to_i.times.map { icon_tag("star", size: "small") })
    end
  end
end
