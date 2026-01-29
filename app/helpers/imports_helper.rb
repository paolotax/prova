# frozen_string_literal: true

module ImportsHelper
  def import_status_bg(import)
    case import.status
    when "pending"
      "bg-gray-100"
    when "processing"
      "bg-blue-100"
    when "completed"
      import.errors_count > 0 ? "bg-yellow-100" : "bg-green-100"
    when "failed"
      "bg-red-100"
    else
      "bg-gray-100"
    end
  end

  def import_status_icon(import)
    case import.status
    when "pending"
      tag.svg(class: "w-6 h-6 text-gray-600") do
        tag.path(
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z",
          stroke: "currentColor",
          fill: "none"
        )
      end
    when "processing"
      tag.svg(class: "w-6 h-6 text-blue-600 animate-spin", viewBox: "0 0 24 24") do
        safe_join([
          tag.circle(
            cx: "12", cy: "12", r: "10",
            stroke: "currentColor", "stroke-width": "4",
            fill: "none", class: "opacity-25"
          ),
          tag.path(
            fill: "currentColor", class: "opacity-75",
            d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          )
        ])
      end
    when "completed"
      if import.errors_count > 0
        tag.svg(class: "w-6 h-6 text-yellow-600", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path(
            "stroke-linecap": "round",
            "stroke-linejoin": "round",
            "stroke-width": "2",
            d: "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          )
        end
      else
        tag.svg(class: "w-6 h-6 text-green-600", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path(
            "stroke-linecap": "round",
            "stroke-linejoin": "round",
            "stroke-width": "2",
            d: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          )
        end
      end
    when "failed"
      tag.svg(class: "w-6 h-6 text-red-600", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        tag.path(
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M6 18L18 6M6 6l12 12"
        )
      end
    else
      ""
    end
  end

  def import_type_color(import_type)
    case import_type.to_s
    when "libri" then "blue"
    when "clienti" then "green"
    when "documenti" then "purple"
    when "confezioni" then "orange"
    when "ministeriali" then "teal"
    else "gray"
    end
  end

  def import_type_icon(import_type)
    case import_type.to_s
    when "libri" then "book"
    when "clienti" then "users"
    when "documenti" then "document"
    when "confezioni" then "cube"
    when "ministeriali" then "folder-arrow-down"
    when "libri_avanzato" then "cog"
    when "documenti_avanzato" then "cog"
    else "arrow-down-tray"
    end
  end

  def import_type_label(import_type)
    case import_type.to_s
    when "libri" then "Libri"
    when "clienti" then "Clienti"
    when "documenti" then "Documenti"
    when "confezioni" then "Confezioni"
    when "ministeriali" then "A.I.E."
    when "libri_avanzato" then "Libri avanzato"
    when "documenti_avanzato" then "Documenti avanzato"
    else import_type.to_s.humanize
    end
  end

  def import_type_text_class(import_type)
    case import_type.to_s
    when "libri" then "txt-link"
    when "clienti" then "txt-positive"
    when "documenti" then "txt-feature"
    when "confezioni" then "txt-alert"
    when "ministeriali" then "txt-subtle"
    else "txt-subtle"
    end
  end
end
