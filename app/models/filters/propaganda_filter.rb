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
  class PropagandaFilter < Base
    include PropagandaFilter::Fields
    include PropagandaFilter::Summarized

    def scuole
      result = Current.scuole
        .where.not(id: Scuola.where.not(direzione_id: nil).select(:direzione_id))

      if terms.present?
        ids = result.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = result.where(id: ids)
      end

      result = result.where(provincia: province) if province.present?
      result = result.where(area: aree) if aree.present?

      result
        .includes(:direzione)
        .left_joins(:direzione)
        .order(:provincia, :area, Arel.sql("COALESCE(direzioni_scuole.denominazione, scuole.denominazione)"), :denominazione)
    end

    alias_method :results, :scuole
  end
end
