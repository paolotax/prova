module Filters
  class GiacenzaFilter < Base
    include GiacenzaFilter::Fields
    include GiacenzaFilter::Summarized

    STATI = {
      "adottati"     => "Adottati",
      "fabbisogno"   => "Con fabbisogno",
      "impegnati"    => "Da consegnare",
      "sotto_scorta" => "Disponibilità negativa"
    }.freeze

    LIBERO_SQL = Giacenza::Columns::LIBERO_SQL

    def libri
      target_account = account || Current.account
      result = target_account.libri.left_joins(:giacenza)

      if terms.present?
        # PgSearch non è compatibile con DISTINCT, quindi usiamo una subquery
        ids = target_account.libri.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = result.where(libri: { id: ids })
      end

      result = result.joins(:editore).where(editori: { editore: editori }) if editori.present?

      case stato
      when "adottati"
        # Il counter comprende solo le adozioni mie con da_acquistare = true.
        result = result.where("libri.adozioni_count > 0")
      when "fabbisogno"
        result = result.where("libri.adozioni_count > (#{LIBERO_SQL})")
      when "impegnati"
        result = result.where("COALESCE(giacenze.impegnato, 0) > 0")
      when "sotto_scorta"
        result = result.where("#{LIBERO_SQL} < 0")
      end

      result
    end

    alias_method :results, :libri
  end
end
