module Filters
  class Cliente < Base
    include Cliente::Fields
    include Cliente::Summarized

    def clienti
      target_account = account || Current.account
      result = target_account.clienti

      if terms.present?
        ids = result.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = target_account.clienti.where(id: ids)
      end

      result = result.where(comune: comuni) if comuni.present?
      result = result.where(tipo_cliente: tipi) if tipi.present?
      result = result.order(sorted_by.to_s)
      result.distinct
    end

    alias_method :results, :clienti
  end
end
