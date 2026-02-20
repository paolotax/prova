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
  class ScuolaFilter < Base
    include ScuolaFilter::Fields
    include ScuolaFilter::Summarized

    def scuole
      base_scope = Current.scuole
      result = base_scope.includes(:import_scuola, :appunti, classi: :adozioni)

      if terms.present?
        # PgSearch non è compatibile con DISTINCT, quindi usiamo una subquery
        ids = result.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = base_scope.where(id: ids).includes(:import_scuola, :appunti, classi: :adozioni)
      end

      result = result.where(comune: comuni) if comuni.present?
      result = result.where(tipo_scuola: tipi_scuola) if tipi_scuola.present?
      result = filter_con_appunti(result) if con_appunti?
      result = filter_con_mie_adozioni(result) if con_mie_adozioni?
      result = filter_con_adozioni_concorrenza(result) if con_adozioni_concorrenza?
      if sorted_by.per_direzione?
        # DISTINCT prima, poi join+order sulla subquery (PG non accetta ORDER BY COALESCE con DISTINCT)
        ids = result.distinct.pluck(:id)
        Current.scuole.where(id: ids)
          .includes(:import_scuola, :appunti, :direzione, :plessi, classi: :adozioni)
          .left_joins(:direzione)
          .order(
            Arel.sql("COALESCE(direzioni_scuole.comune, scuole.comune)"),
            Arel.sql("COALESCE(direzioni_scuole.denominazione, scuole.denominazione)"),
            :tipo_scuola, :denominazione
          )
      else
        result.order(sorted_by.to_s).distinct
      end
    end

    alias_method :results, :scuole

    private

    def filter_con_appunti(scope)
      # Use .aperti scope instead of where.missing(:closure) for uuid/varchar compatibility
      scope.joins(:appunti).merge(Current.user.appunti.attivi)
    end

    def filter_con_mie_adozioni(scope)
      scope.joins(classi: :adozioni).where(adozioni: { mia: true })
    end

    def filter_con_adozioni_concorrenza(scope)
      scope.joins(classi: :adozioni).where(adozioni: { mia: false })
    end
  end
end
