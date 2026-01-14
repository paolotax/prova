# == Schema Information
#
# Table name: scuola_filters
#
#  id            :uuid             not null, primary key
#  fields        :jsonb
#  params_digest :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid
#  creator_id    :bigint
#
# Indexes
#
#  index_scuola_filters_on_account_id    (account_id)
#  index_scuola_filters_on_creator_id    (creator_id)
#  index_scuola_filters_on_params_digest (params_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#
class ScuolaFilter < ApplicationRecord
  include Fields, Params

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { Current.account }

  def scuole
    target_account = account || Current.account
    result = target_account.scuole.includes(:classi, :appunti)
    result = result.search_all_word(terms.first) if terms.present?
    result = result.where(comune: comuni) if comuni.present?
    result = filter_con_appunti(result) if con_appunti?
    result = filter_con_adozioni_mie(result) if con_adozioni_mie?
    result = result.order(sorted_by.to_s)
    result.distinct
  end

  def cacheable?
    persisted?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key params_digest, "scuola_filter"
  end

  private

  def filter_con_appunti(scope)
    scope.joins(:appunti)
  end

  def filter_con_adozioni_mie(scope)
    scope.joins(classi: :adozioni).where(adozioni: { mia: true })
  end
end
