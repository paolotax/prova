module ClassiHelper
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

  # Display adozione libro as compact chip: titolo troncato + editore sotto
  # Yellow for mia, red for nuova_adozione
  def adozione_libro_tag(adozione)
    bg = if adozione.nuova_adozione?
      "background: #fee2e2; color: #991b1b;"
    elsif adozione.mia?
      "background: #fef9c3; color: #854d0e;"
    else
      ""
    end

    content_tag(:span, class: "adozione-libro", style: bg, data: { controller: "tooltip" }) do
      content_tag(:span, truncate(adozione.titolo, length: 20), class: "adozione-libro__titolo") +
      content_tag(:span, adozione.editore, class: "adozione-libro__editore") +
      content_tag(:span, adozione.titolo, class: "for-screen-reader")
    end
  end
end
