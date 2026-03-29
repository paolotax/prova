module Filters
  class PersonaFilter < Base
    include PersonaFilter::Fields
    include PersonaFilter::Summarized

    def persone
      target_account = account || Current.account
      result = target_account.persone

      if terms.present?
        term = "%#{terms.first}%"
        result = result.left_joins(:scuola)
                       .where("persone.cognome ILIKE :q OR persone.nome ILIKE :q OR scuole.denominazione ILIKE :q", q: term)
      end

      if classi.present?
        result = result.joins(persona_classi: :classe)
                       .where(classi: { anno_corso: classi })
      end

      if materie.present?
        result = result.joins(:persona_classi)
                       .where(persona_classi: { materia: materie })
      end

      result = result.where(ruolo: ruoli) if ruoli.present?

      case stato_contatto
      when "con_email"    then result = result.where.not(email: [nil, ""])
      when "con_telefono" then result = result.where.not(cellulare: [nil, ""])
      when "con_scuola"   then result = result.where.not(scuola_id: nil)
      when "senza_scuola" then result = result.where(scuola_id: nil)
      end

      # Subquery to avoid DISTINCT + ORDER BY conflict with scuole columns
      ids = result.reorder(nil).select(:id).distinct
      result = target_account.persone.where(id: ids).includes(:scuola, :classi)

      case sorted_by.to_s
      when "scuola"  then result.left_joins(:scuola).order("scuole.denominazione ASC, persone.cognome, persone.nome")
      when "recenti" then result.order(created_at: :desc)
      else result.order(:cognome, :nome)
      end
    end

    alias_method :results, :persone
  end
end
