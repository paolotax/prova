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
  class Appunto < Base
    include Appunto::Fields
    include Appunto::Summarized

    def appunti(base_scope = nil)
      base_scope ||= ::Appunto.where(account: account || Current.account)
      result = base_scope

      if terms.present?
        # Usa search senza le associazioni problematiche (Action Text con UUID)
        result = result.where(
          "appunti.nome ILIKE :q OR appunti.body ILIKE :q OR appunti.stato ILIKE :q",
          q: "%#{terms.first}%"
        )
      end

      result = result.where(stato: statuses) if statuses.present?
      result = result.with_any_state([state]) if state.present?
      result
    end

    alias_method :results, :appunti
  end
end
