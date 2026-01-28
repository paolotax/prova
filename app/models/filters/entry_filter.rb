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

      # Term search - cerca in appunti e documenti associati
      if terms.present?
        term = terms.first
        appunto_ids = ::Appunto.where(account: account || Current.account)
                               .where("appunti.nome ILIKE :q OR appunti.body ILIKE :q", q: "%#{term}%")
                               .pluck(:id).map(&:to_s)
        documento_ids = ::Documento.joins(:causale)
                                   .where("causali.causale ILIKE :q", q: "%#{term}%")
                                   .pluck(:id).map(&:to_s)

        result = result.where(
          "(entryable_type = 'Appunto' AND entryable_id IN (:appunto_ids)) OR " \
          "(entryable_type = 'Documento' AND entryable_id IN (:documento_ids))",
          appunto_ids: appunto_ids.presence || [""],
          documento_ids: documento_ids.presence || [""]
        )
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
  end
end
