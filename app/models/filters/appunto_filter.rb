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
  class AppuntoFilter < Base
    include AppuntoFilter::Fields
    include AppuntoFilter::Summarized

    def appunti(base_scope = nil)
      base_scope ||= ::Appunto.where(account: account || Current.account)
      result = base_scope

      if terms.present?
        # Ricerca con prefix matching (come pg_search): "ma ki" trova "martin luther king"
        # Usa regex \m per word boundary (inizio parola)
        words = terms.first.split(/\s+/).reject(&:blank?)
        if words.any?
          result = result.left_joins_appuntabile

          # Per ogni parola, deve matchare come prefisso di parola in almeno un campo
          words.each do |word|
            # \m = word boundary in PostgreSQL regex, ~* = case insensitive
            pattern = "\\m#{word}"
            result = result.where(<<~SQL, q: pattern)
              appunti.nome ~* :q
              OR appunti.body ~* :q
              OR appunti.email ~* :q
              OR appunti.telefono ~* :q
              OR scuole.denominazione ~* :q
              OR scuole.comune ~* :q
              OR clienti.denominazione ~* :q
              OR clienti.comune ~* :q
              OR action_text_rich_texts.body ~* :q
            SQL
          end
        end
      end

      # Anno filter
      if anno.present?
        result = result.where("EXTRACT(YEAR FROM appunti.created_at) = ?", anno)
      end

      result = result.with_any_state([state]) if state.present?
      result
    end

    alias_method :results, :appunti
  end
end
