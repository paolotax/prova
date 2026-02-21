module ScuoleHelper
  GRADO_LABELS = {
    "E" => "Primaria",
    "M" => "Secondaria 1° grado",
    "N" => "Secondaria 2° grado",
    "I" => "Infanzia",
    "IC" => "Istituti Comprensivi",
    "altro" => "Altro"
  }.freeze

  def grado_label(grado)
    GRADO_LABELS[grado] || grado&.capitalize || "Altro"
  end

  def scuola_color(scuola)
    case scuola.tipo_scuola
    when "ISTITUTO COMPRENSIVO"                 then "oklch(0.6 0.15 250)"  # blue
    when "SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE"
                                                then "oklch(0.6 0.15 160)"  # emerald
    when "SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE"
                                                then "oklch(0.6 0.15 45)"   # amber
    when "LICEO SCIENTIFICO"                    then "oklch(0.6 0.15 280)"  # violet
    when "LICEO CLASSICO"                       then "oklch(0.6 0.15 320)"  # pink
    when "LICEO LINGUISTICO"                    then "oklch(0.6 0.15 200)"  # cyan
    when /\AISTITUTO TECNICO/                   then "oklch(0.6 0.15 15)"   # rose
    when "ISTITUTO PROFESSIONALE"               then "oklch(0.6 0.15 100)"  # lime
    when "SCUOLA INFANZIA", "SCUOLA INFANZIA NON STATALE"
                                                then "oklch(0.6 0.15 70)"   # orange
    else "oklch(0.6 0.01 0)"  # gray default
    end
  end

  def scuola_badge_class(scuola)
    return "badge--positive" if scuola.classi.any?
    return "badge--warning" if scuola.priorita.to_i > 3
    ""
  end

  def regioni_options
    ImportScuola.distinct.where.not(REGIONE: [nil, ""]).order(:REGIONE).pluck(:REGIONE).map { |r| [r.titleize, r] }
  end

  def tipi_scuola_options
    TipoScuola.where.not(tipo: "Non Disponibile").order(:grado, :tipo).pluck(:tipo).map { |t| [t.titleize, t] }
  end

  def priorita_stars(priorita)
    return "" if priorita.to_i.zero?
    content_tag(:span, class: "flex gap-quarter", style: "color: var(--color-warning);") do
      safe_join(priorita.to_i.times.map { icon_tag("star", size: "small") })
    end
  end
end
