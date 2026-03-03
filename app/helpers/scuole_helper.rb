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

  def scuola_badge_class(scuola)
    return "badge--positive" if scuola.classi.any?
    return "badge--warning" if scuola.priorita.to_i > 3
    ""
  end

  def regioni_options
    ImportScuola.distinct.where.not(REGIONE: [nil, ""]).order(:REGIONE).pluck(:REGIONE).map { |r| [r.titleize, r] }
  end

  def province_options
    province_account = Current.account&.zone&.distinct&.pluck(:provincia) || []
    Zona.where(provincia: province_account).select(:provincia, :sigla).distinct.order(:provincia).map { |z| [z.sigla, z.provincia, { "data-sigla" => z.sigla }] }
  end

  def zone_data_for_selects
    province_account = Current.account&.zone&.distinct&.pluck(:provincia) || []
    Zona.where(provincia: province_account).order(:provincia, :comune).pluck(:provincia, :sigla, :comune).group_by(&:first).transform_values do |rows|
      { sigla: rows.first[1], comuni: rows.map(&:last).uniq }
    end
  end

  def account_multi_regione?
    Current.account&.zone&.select(:regione)&.distinct&.count.to_i > 1
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
