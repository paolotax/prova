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
  class Scuola < Base
    include Scuola::Fields

    def scuole
      target_account = account || Current.account
      result = target_account.scuole.includes(:classi, :appunti)
      result = result.search_all_word(terms.first) if terms.present?
      result = result.where(comune: comuni) if comuni.present?
      result = filter_con_appunti(result) if con_appunti?
      result = filter_con_mie_adozioni(result) if con_mie_adozioni?
      result = filter_con_adozioni_concorrenza(result) if con_adozioni_concorrenza?
      result = result.order(sorted_by.to_s)
      result.distinct
    end

    alias_method :results, :scuole

    private

    def filter_con_appunti(scope)
      scope.joins(:appunti)
    end

    def filter_con_mie_adozioni(scope)
      scope.joins(classi: :adozioni).where(adozioni: { mia: true })
    end

    def filter_con_adozioni_concorrenza(scope)
      scope.joins(classi: :adozioni).where(adozioni: { mia: false })
    end
  end
end
