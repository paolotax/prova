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
  class ClienteFilter < Base
    include ClienteFilter::Fields
    include ClienteFilter::Summarized

    def clienti
      target_account = account || Current.account
      result = target_account.clienti

      if terms.present?
        ids = result.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = target_account.clienti.where(id: ids)
      end

      result = result.where(comune: comuni) if comuni.present?
      result = result.where(tipo_cliente: tipi) if tipi.present?
      result = result.fornitori if fornitori.present?
      result = result.order(sorted_by.to_s)
      result.distinct
    end

    alias_method :results, :clienti
  end
end
