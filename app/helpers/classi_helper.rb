module ClassiHelper
  # Color per tipo_scuola (oklch like causale_color)
  def tipo_scuola_color(tipo_scuola)
    key = tipo_scuola.to_s.upcase
    case key
    when /PRIMO GRADO/           then "var(--color-card-5)"  # emerald — medie
    when /COMPRENSIVO|SUPERIORE/ then "var(--color-card-5)"
    when /PRIMARIA/              then "var(--color-card-default)"  # blue — elementari
    when /LICEO SCIENTIFICO/     then "var(--color-card-6)"  # indigo
    when /LICEO CLASSICO/        then "var(--color-card-6)" # purple
    when /LICEO ARTISTICO/       then "var(--color-card-6)"  # pink
    when /MAGISTRALE/            then "var(--color-card-6)"  # fuchsia
    when /TEC.*COMMERC|TEC.*GEOM|TEC.*TURIS/ then "var(--color-card-4)" # orange — tecnici commerciali
    when /TEC.*INDUSTR|TEC.*AGRAR|TEC.*AERON/ then "var(--color-card-4)" # amber — tecnici industriali
    when /PROF.*SERVIZ|PROF.*COMMERC|PROF.*PUBBLIC/ then "var(--color-card-8)" # rose — professionali servizi
    when /PROF.*INDUSTR|PROF.*ARTIG|PROF.*AGRIC/ then "var(--color-card-8)" # red-orange — professionali industria
    when /ARTE/                  then "var(--color-card-6)"  # magenta
    when /SECONDO/               then "var(--color-card-5)"  # magenta
    else "var(--color-card-1)" # gray default
    end
  end

  # Compact classi notation (inverse of ANARPE parser)
  # [1A, 2A, 3F] → "12A 3F"
  # [1E, 2E, 3E] → "123E"
  # [3L, 4P, 5N] → "3L 4P 5N"
  def compact_classi(classi)
    grouped = classi.sort_by { |c| [c.sezione, c.anno_corso] }
                    .group_by(&:sezione)

    grouped.map do |sezione, classes|
      anni = classes.map(&:anno_corso).sort.join
      "#{anni}#{sezione}"
    end.join(" ")
  end

  # Compact classi with links
  def compact_classi_links(classi, scuola)
    grouped = classi.sort_by { |c| [c.sezione, c.anno_corso] }
                    .group_by(&:sezione)

    tokens = grouped.map do |sezione, classes|
      anni = classes.map(&:anno_corso).sort.join
      links = classes.sort_by(&:anno_corso).map do |c|
        link_to c.anno_corso.to_s, scuola_classe_path(scuola, c), class: "txt-link"
      end
      safe_join(links) + sezione
    end

    safe_join(tokens, " ")
  end

  # Badge arrotondate per ogni classe: "1A" "2A" "3A" con link
  # classe_styles: hash { classe_id => :mia | :nuova | nil }
  def classi_badge_links(classi, scuola, classe_styles: nil, hover_target: false)
    classi.sort_by { |c| [c.anno_corso, c.sezione] }.map do |classe|
      variant = classe_styles&.dig(classe.id)
      style = case variant
      when :nuova_mia
        "background: var(--color-negative); color: var(--color-ink-inverted);"
      when :mia
        "background: var(--card-color); color: var(--color-ink-inverted);"
      when :nuova_altri
        "background: transparent; color: var(--color-negative); box-shadow: inset 0 0 0 1px var(--color-negative);"
      when :grey
        "background: var(--color-ink-light); color: var(--color-ink-inverted);"
      when nil
        if classe_styles
          "background: transparent; color: var(--card-color); box-shadow: inset 0 0 0 1px var(--card-color);"
        else
          "background: var(--card-color); color: var(--color-ink-inverted);"
        end
      end
      link_data = { turbo_frame: "_top" }
      if hover_target
        link_data[:libro_hover_target] = "badge"
        link_data[:classe_id] = classe.id
      end
      link_to classe.nome_breve, scuola_classe_path(scuola, classe),
        class: "btn txt-small",
        style: style,
        data: link_data
    end.then { |links| safe_join(links, " ") }
  end

  # Display adozione libro as compact chip: titolo troncato + editore sotto
  # Yellow for mia, red for nuova_adozione
  def adozione_libro_tag(adozione, data: {})
    bg = if adozione.nuova_adozione?
      "background: #fee2e2; color: #991b1b;"
    elsif adozione.mia?
      "background: color-mix(in srgb, var(--card-color) 15%, var(--color-canvas)); color: color-mix(in srgb, var(--card-color) 75%, var(--color-ink));"
    else
      ""
    end

    content_tag(:span, class: "adozione-libro", style: bg, data: data) do
      content_tag(:span, adozione.titolo, class: "adozione-libro__titolo") +
      content_tag(:span, class: "adozione-libro__footer") do
        content_tag(:span, adozione.editore, class: "adozione-libro__editore") +
        content_tag(:span, number_to_currency(adozione.prezzo), class: "adozione-libro__prezzo")
      end
    end
  end
end
