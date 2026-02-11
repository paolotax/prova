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
  class EntryFilter < Base
    include EntryFilter::Fields
    include EntryFilter::Summarized

    def entries(base_scope = nil)
      base_scope ||= ::Entry.where(account: account || Current.account)
      result = base_scope

      # Term search - prefix matching: "ma ki" trova "martin luther king"
      # Usa subquery SQL per evitare round-trip Ruby ↔ DB
      if terms.present?
        words = terms.first.split(/\s+/).reject(&:blank?)
        if words.any?
          appunti_sub = appunti_subquery(words)
          documenti_sub = documenti_subquery(words)

          result = result.where(<<~SQL)
            (entries.entryable_type = 'Appunto' AND entries.entryable_id::uuid IN (#{appunti_sub}))
            OR
            (entries.entryable_type = 'Documento' AND entries.entryable_id::uuid IN (#{documenti_sub}))
          SQL
        end
      end

      # Entryable type filter
      result = result.where(entryable_type: entryable_type) if entryable_type.present?

      # State filter
      case state
      when "active" then result = result.active
      when "closed" then result = result.closed
      when "postponed" then result = result.postponed
      end

      # Golden filter
      result = result.golden if golden == "true"

      result
    end

    alias_method :results, :entries

    private

    def account_id
      (account || Current.account).id
    end

    def word_conditions(words, &block)
      words.map { |word|
        pattern = ActiveRecord::Base.connection.quote("\\m#{word}")
        block.call(pattern)
      }.join(" AND ")
    end

    def appunti_subquery(words)
      conditions = word_conditions(words) do |pattern|
        <<~SQL.squish
          (appunti.nome ~* #{pattern}
          OR appunti.body ~* #{pattern}
          OR scuole.denominazione ~* #{pattern}
          OR scuole.comune ~* #{pattern}
          OR clienti.denominazione ~* #{pattern}
          OR clienti.comune ~* #{pattern}
          OR classi.anno_corso::text ~* #{pattern}
          OR classi.sezione ~* #{pattern}
          OR CONCAT(classi.anno_corso, classi.sezione) ~* #{pattern}
          OR scuole_classe.denominazione ~* #{pattern}
          OR scuole_classe.comune ~* #{pattern}
          OR action_text_rich_texts.body ~* #{pattern})
        SQL
      end

      <<~SQL.squish
        SELECT appunti.id FROM appunti
        LEFT JOIN scuole ON appunti.appuntabile_type = 'Scuola' AND appunti.appuntabile_id = scuole.id
        LEFT JOIN clienti ON appunti.appuntabile_type = 'Cliente' AND appunti.appuntabile_id = clienti.id
        LEFT JOIN classi ON appunti.appuntabile_type = 'Classe' AND appunti.appuntabile_id = classi.id
        LEFT JOIN scuole AS scuole_classe ON classi.scuola_id = scuole_classe.id
        LEFT JOIN action_text_rich_texts ON action_text_rich_texts.record_type = 'Appunto'
          AND action_text_rich_texts.record_id = appunti.id::text
          AND action_text_rich_texts.name = 'content'
        WHERE appunti.account_id = #{ActiveRecord::Base.connection.quote(account_id)}
        AND #{conditions}
      SQL
    end

    def documenti_subquery(words)
      conditions = word_conditions(words) do |pattern|
        <<~SQL.squish
          (causali.causale ~* #{pattern}
          OR documenti.referente ~* #{pattern}
          OR documenti.note ~* #{pattern}
          OR doc_scuole.denominazione ~* #{pattern}
          OR doc_scuole.comune ~* #{pattern}
          OR doc_clienti.denominazione ~* #{pattern}
          OR doc_clienti.comune ~* #{pattern}
          OR doc_classi.anno_corso::text ~* #{pattern}
          OR doc_classi.sezione ~* #{pattern}
          OR CONCAT(doc_classi.anno_corso, doc_classi.sezione) ~* #{pattern}
          OR doc_scuole_classe.denominazione ~* #{pattern}
          OR doc_scuole_classe.comune ~* #{pattern})
        SQL
      end

      <<~SQL.squish
        SELECT documenti.id FROM documenti
        LEFT JOIN causali ON causali.id = documenti.causale_id
        LEFT JOIN scuole AS doc_scuole ON documenti.clientable_type = 'Scuola' AND documenti.clientable_id = doc_scuole.id
        LEFT JOIN clienti AS doc_clienti ON documenti.clientable_type = 'Cliente' AND documenti.clientable_id = doc_clienti.id
        LEFT JOIN classi AS doc_classi ON documenti.clientable_type = 'Classe' AND documenti.clientable_id = doc_classi.id
        LEFT JOIN scuole AS doc_scuole_classe ON doc_classi.scuola_id = doc_scuole_classe.id
        WHERE documenti.account_id = #{ActiveRecord::Base.connection.quote(account_id)}
        AND #{conditions}
      SQL
    end
  end
end
