module Filters
  class GiacenzaFilter < Base
    include GiacenzaFilter::Fields
    include GiacenzaFilter::Summarized

    STATI = {
      "adottati"      => "Adottati",
      "campionario"   => "In campionario",
      "saggi_100"     => "Saggi 100",
      "saggi_50"      => "Saggi 50",
      "scarico_saggi" => "Scarico saggi",
      "venduti"       => "Venduti",
      "impegnati"     => "Da consegnare"
    }.freeze

    # Condizioni SQL per ogni stato: le chiavi sono validate dall'accessor
    # `stati` (& STATI.keys), quindi qui non entra input utente grezzo.
    CONDIZIONI_STATO = {
      "adottati"      => "libri.adozioni_count > 0",
      "campionario"   => "COALESCE(conteggi.campionario, 0) > 0",
      "saggi_100"     => "COALESCE(conteggi.saggi_100, 0) > 0",
      "saggi_50"      => "COALESCE(conteggi.saggi_50, 0) > 0",
      "scarico_saggi" => "COALESCE(conteggi.scarico_saggi, 0) > 0",
      "venduti"       => "COALESCE(conteggi.venduti, 0) > 0",
      "impegnati"     => "COALESCE(conteggi.da_consegnare, 0) > 0"
    }.freeze

    def libri(ignora_stati: false)
      target_account = account || Current.account
      conteggi = Giacenza::Conteggi.new(account: target_account, anno: anno)

      result = target_account.libri
        .joins("LEFT JOIN (#{conteggi.subquery}) conteggi ON conteggi.libro_id = libri.id")
        .select("libri.*", *conteggi_select)

      if terms.present?
        # PgSearch non è compatibile con DISTINCT, quindi usiamo una subquery
        ids = target_account.libri.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = result.where(libri: { id: ids })
      end

      result = result.joins(:editore).where(editori: { editore: editori }) if editori.present?
      result = result.joins(:categoria).where("categorie.nome_categoria in (?)", categorie) if categorie.present?

      if !ignora_stati && stati.any?
        # OR fra le condizioni: le chiavi sono validate (fetch su chiavi note).
        result = result.where(stati.map { |s| "(#{CONDIZIONI_STATO.fetch(s)})" }.join(" OR "))
      end

      result
    end

    alias_method :results, :libri

    private

      # Alias COALESCE-ati così celle e sort leggono valori mai NULL.
      def conteggi_select
        (Giacenza::Conteggi::CAUSALI.keys + %i[venduti da_consegnare venduto_cents]).map do |col|
          "COALESCE(conteggi.#{col}, 0) AS #{col}"
        end
      end
  end
end
