# frozen_string_literal: true

module ImportsHelper
  def import_type_icon(import_type)
    case import_type.to_s
    when "libri" then "book"
    when "clienti" then "users"
    when "documenti" then "document"
    when "confezioni" then "cube"
    when "ministeriali" then "folder-arrow-down"
    when "insegnanti" then "academic-cap"
    when "adozioni_comunicate" then "arrow-down-tray"
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
    when "insegnanti" then "Insegnanti"
    when "adozioni_comunicate" then "Adozioni editore"
    else import_type.to_s.humanize
    end
  end

  def import_type_text_class(import_type)
    case import_type.to_s
    when "libri" then "txt-link"
    when "clienti" then "txt-positive"
    when "documenti" then "txt-feature"
    when "confezioni" then "txt-alert"
    when "adozioni_comunicate" then "txt-feature"
    else "txt-subtle"
    end
  end
end
