require "test_helper"

module Filters
  class GiacenzaFilterTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :editori, :categorie, :libri

    setup do
      @fizzy = accounts(:fizzy)
      @user = users(:one)
      Current.account = @fizzy
      Current.user = @user

      # 12 adozioni contro 8-3=5 di disponibilità libera => fabbisogno 7
      @adottato = libri(:libro_fizzy)
      @adottato.update_column(:adozioni_count, 12)
      Giacenza.create!(account: @fizzy, libro: @adottato,
        disponibile: 8, impegnato: 3, venduto_copie: 4, venduto_cents: 6000)

      # Nessuna adozione, magazzino in negativo (reso più del carico):
      # per definizione ha comunque fabbisogno (0 - (-2) = 2)
      @sotto_scorta = libri(:confezione_fizzy)
      @sotto_scorta.update_column(:adozioni_count, 0)
      Giacenza.create!(account: @fizzy, libro: @sotto_scorta,
        disponibile: -2, impegnato: 0)

      # Coperto: nessuna adozione, disponibilità abbondante
      @coperto = libri(:fascicolo_uno)
      @coperto.update_column(:adozioni_count, 0)
      Giacenza.create!(account: @fizzy, libro: @coperto,
        disponibile: 10, impegnato: 0)
    end

    teardown { Current.reset }

    test "senza filtri restituisce tutti i libri dell'account" do
      filter = GiacenzaFilter.from_params({})
      assert_equal @fizzy.libri.count, filter.libri.count
      assert_equal "Tutte le giacenze", filter.summary
    end

    test "stato fabbisogno restituisce solo i titoli scoperti" do
      filter = GiacenzaFilter.from_params(stato: "fabbisogno")
      assert_includes filter.libri, @adottato
      assert_not_includes filter.libri, @coperto
    end

    test "stato impegnati restituisce solo i titoli da consegnare" do
      filter = GiacenzaFilter.from_params(stato: "impegnati")
      assert_includes filter.libri, @adottato
      assert_not_includes filter.libri, @sotto_scorta
      assert_not_includes filter.libri, @coperto
    end

    test "stato sotto_scorta restituisce le disponibilità negative" do
      filter = GiacenzaFilter.from_params(stato: "sotto_scorta")
      assert_includes filter.libri, @sotto_scorta
      assert_not_includes filter.libri, @adottato
      assert_not_includes filter.libri, @coperto
    end

    test "stato adottati usa il counter delle adozioni" do
      filter = GiacenzaFilter.from_params(stato: "adottati")
      assert_includes filter.libri, @adottato
      assert_not_includes filter.libri, @sotto_scorta
    end

    test "stato sconosciuto viene ignorato" do
      filter = GiacenzaFilter.from_params(stato: "boh")
      assert_nil filter.stato
      assert_equal @fizzy.libri.count, filter.libri.count
    end

    test "filtra per editore" do
      filter = GiacenzaFilter.from_params(editori: [ "Mondadori" ])
      assert_includes filter.libri, @adottato
      assert filter.libri.all? { |libro| libro.editore.editore == "Mondadori" }
    end

    test "terms cerca nel titolo" do
      filter = GiacenzaFilter.from_params(terms: [ "confezione atlante" ])
      assert_includes filter.libri, @sotto_scorta
      assert_not_includes filter.libri, @adottato
    end

    test "summary compone terms, stato ed editori" do
      filter = GiacenzaFilter.from_params(terms: [ "atlante" ], stato: "fabbisogno", editori: [ "Mondadori" ])
      assert_equal "\"atlante\", Con fabbisogno e Mondadori", filter.summary
    end

    test "from_params normalizza e riusa lo stesso digest" do
      digest_a = GiacenzaFilter.from_params(stato: "fabbisogno").params_digest
      digest_b = GiacenzaFilter.from_params(stato: "fabbisogno", terms: []).params_digest
      assert_equal digest_a, digest_b
    end
  end
end
