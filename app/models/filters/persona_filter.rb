# == Schema Information
#
# Table name: filters
#
#  id            :uuid             not null, primary key
#  fields        :jsonb
#  params_digest :string
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid
#  creator_id    :bigint
#
# Indexes
#
#  index_filters_on_account_id              (account_id)
#  index_filters_on_creator_id              (creator_id)
#  index_filters_on_type_and_params_digest  (type,params_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#
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
