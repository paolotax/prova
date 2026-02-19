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
  class LibroFilter < Base
    include LibroFilter::Fields
    include LibroFilter::Summarized

    def libri
      target_account = account || Current.account
      result = target_account.libri

      if terms.present?
        # PgSearch non è compatibile con DISTINCT, quindi usiamo una subquery
        ids = result.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = target_account.libri.where(id: ids)
      end

      result = result.joins(:categoria).where("categorie.nome_categoria in (?)", categorie) if categorie.present?
      result = result.joins(:editore).where("editori.editore in (?)", editori) if editori.present?
      result = result.where(disciplina: discipline) if discipline.present?
      result = result.where(classe: classi) if classi.present?
      result = result.includes(:editore, :categoria).preload(edizione_titolo: { copertina_attachment: :blob })
      result = result.order(sorted_by.to_s)
      result.distinct
    end

    alias_method :results, :libri
  end
end
