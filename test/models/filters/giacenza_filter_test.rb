require "test_helper"

module Filters
  class GiacenzaFilterTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

    setup do
      @fizzy = accounts(:fizzy)
      @user = users(:one)
      @cliente = clienti(:cliente_fizzy)
      Current.account = @fizzy
      Current.user = @user

      # Libri dedicati: le fixture righe/documenti insistono su libro_fizzy e
      # inquinerebbero i conteggi. Creiamo scenari deterministici.
      @campionario = crea_libro("Campionario libro", editore: editori(:mondadori))
      crea_documento(causali(:campionario), libro: @campionario, quantita: 10)
      crea_documento(causali(:campionario), libro: @campionario, quantita: 4,
                     data: 1.year.ago.to_date)

      @venduto = crea_libro("Venduto libro", editore: editori(:mondadori))
      vendita = crea_documento(causali(:fattura), libro: @venduto, quantita: 6)
      vendita.consegna_parziale!({ vendita.documento_righe.first.id => 4 })

      @adottato = crea_libro("Adottato libro", editore: editori(:pearson))
      @adottato.update_column(:adozioni_count, 12)

      # Solo campionario dell'anno scorso: escluso col default, incluso con anno esplicito.
      @anno_scorso = crea_libro("Anno scorso libro", editore: editori(:mondadori))
      crea_documento(causali(:campionario), libro: @anno_scorso, quantita: 5,
                     data: 1.year.ago.to_date)

      # Nessun conteggio, nessuna adozione.
      @neutro = crea_libro("Neutro libro", editore: editori(:zanichelli))
    end

    teardown { Current.reset }

    test "senza filtri restituisce tutti i libri dell'account" do
      filter = GiacenzaFilter.from_params({})
      # La scope porta una select custom (alias conteggi): il conteggio va fatto
      # scartandola, come nel controller.
      assert_equal @fizzy.libri.count, filter.libri.except(:select).count
      assert_equal "Tutte le giacenze", filter.summary
    end

    test "stato campionario include i libri con campionario dell'anno ed esclude gli altri" do
      filter = GiacenzaFilter.from_params(stati: [ "campionario" ])
      assert_includes filter.libri, @campionario
      assert_not_includes filter.libri, @venduto
      assert_not_includes filter.libri, @neutro
      assert_not_includes filter.libri, @anno_scorso
    end

    test "stati multipli compongono in OR" do
      # adottati OR venduti: includono il solo-adottato E il solo-venduto,
      # escludono il neutro.
      filter = GiacenzaFilter.from_params(stati: [ "adottati", "venduti" ])
      assert_includes filter.libri, @adottato
      assert_includes filter.libri, @venduto
      assert_not_includes filter.libri, @neutro
      assert_not_includes filter.libri, @campionario
    end

    test "stato venduti include solo i libri con copie consegnate" do
      filter = GiacenzaFilter.from_params(stati: [ "venduti" ])
      assert_includes filter.libri, @venduto
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "stato impegnati include i libri con residuo da consegnare" do
      filter = GiacenzaFilter.from_params(stati: [ "impegnati" ])
      assert_includes filter.libri, @venduto
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "stato saggi_100 include solo i libri con saggi 100 dell'anno" do
      con_saggi = crea_libro("Saggi100 libro", editore: editori(:mondadori))
      crea_documento(causali(:saggi_100), libro: con_saggi, quantita: 3)

      filter = GiacenzaFilter.from_params(stati: [ "saggi_100" ])
      assert_includes filter.libri, con_saggi
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "stato saggi_50 include solo i libri con saggi 50 dell'anno" do
      con_saggi = crea_libro("Saggi50 libro", editore: editori(:mondadori))
      crea_documento(causali(:saggi_50), libro: con_saggi, quantita: 2)

      filter = GiacenzaFilter.from_params(stati: [ "saggi_50" ])
      assert_includes filter.libri, con_saggi
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "stato scarico_saggi include solo i libri con scarico saggi dell'anno" do
      con_scarico = crea_libro("Scarico libro", editore: editori(:mondadori))
      crea_documento(causali(:scarico_saggi), libro: con_scarico, quantita: 7)

      filter = GiacenzaFilter.from_params(stati: [ "scarico_saggi" ])
      assert_includes filter.libri, con_scarico
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "libri(ignora_stati: true) ignora gli stati ma rispetta editori e anno" do
      # Lo stato campionario, ignorato, non deve escludere il venduto.
      filter = GiacenzaFilter.from_params(stati: [ "campionario" ])
      assert_includes filter.libri(ignora_stati: true), @venduto
      assert_includes filter.libri(ignora_stati: true), @campionario
      assert_includes filter.libri(ignora_stati: true), @neutro

      # Editore resta rispettato.
      per_editore = GiacenzaFilter.from_params(stati: [ "campionario" ], editori: [ "Mondadori" ])
      assert_includes per_editore.libri(ignora_stati: true), @campionario
      assert_not_includes per_editore.libri(ignora_stati: true), @adottato

      # Anno resta rispettato: col default (anno corrente) i conteggi restano quelli dell'anno.
      libro = filter.libri(ignora_stati: true).find { |l| l.id == @campionario.id }
      assert_equal 10, libro[:campionario].to_i
    end

    test "stato adottati usa il counter delle adozioni" do
      filter = GiacenzaFilter.from_params(stati: [ "adottati" ])
      assert_includes filter.libri, @adottato
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "stati sconosciuti (fabbisogno rimosso) vengono scartati" do
      filter = GiacenzaFilter.from_params(stati: [ "fabbisogno" ])
      assert_empty filter.stati
      assert_equal @fizzy.libri.count, filter.libri.except(:select).count
    end

    test "anno di default legge i conteggi dell'anno corrente" do
      filter = GiacenzaFilter.from_params({})
      assert_equal Date.current.year, filter.anno
      libro = filter.libri.find { |l| l.id == @campionario.id }
      assert_equal 10, libro[:campionario].to_i
    end

    test "anno esplicito cambia conteggi e risultati" do
      anno = 1.year.ago.year
      filter = GiacenzaFilter.from_params(anno: anno)
      assert_equal anno, filter.anno

      libro = filter.libri.find { |l| l.id == @campionario.id }
      assert_equal 4, libro[:campionario].to_i

      stato = GiacenzaFilter.from_params(stati: [ "campionario" ], anno: anno)
      assert_includes stato.libri, @anno_scorso
    end

    test "gli alias dei conteggi sono leggibili sui record" do
      filter = GiacenzaFilter.from_params({})
      venduto = filter.libri.find { |l| l.id == @venduto.id }
      assert_equal 4, venduto[:venduti].to_i
      assert_equal 2, venduto[:da_consegnare].to_i
      assert venduto[:venduto_cents].to_i.positive?
    end

    test "filtra per editore" do
      filter = GiacenzaFilter.from_params(editori: [ "Mondadori" ])
      assert_includes filter.libri, @campionario
      assert_not_includes filter.libri, @adottato
      assert filter.libri.all? { |libro| libro.editore.editore == "Mondadori" }
    end

    test "filtra per categoria" do
      para = Libro.create!(account: @fizzy, user: @user, titolo: "Parascolastico libro",
                           codice_isbn: "TEST-#{SecureRandom.hex(4)}", prezzo_in_cents: 10000,
                           editore: editori(:mondadori), categoria: categorie(:parascolastico))

      filter = GiacenzaFilter.from_params(categorie: [ "parascolastico" ])
      assert_includes filter.libri, para
      assert_not_includes filter.libri, @campionario
      assert_not_includes filter.libri, @neutro
    end

    test "combina categorie e stati" do
      # @campionario è ministeriali e ha campionario > 0.
      solo_categoria = GiacenzaFilter.from_params(categorie: [ "ministeriali" ], stati: [ "campionario" ])
      assert_includes solo_categoria.libri, @campionario
      # Il venduto (ministeriali) non ha campionario: escluso dallo stato.
      assert_not_includes solo_categoria.libri, @venduto
    end

    test "summary include le categorie" do
      una = GiacenzaFilter.from_params(categorie: [ "ministeriali" ])
      assert_includes una.summary, "ministeriali"

      due = GiacenzaFilter.from_params(categorie: [ "ministeriali", "parascolastico" ])
      assert_includes due.summary, "2 categorie"
    end

    test "terms cerca nel titolo" do
      filter = GiacenzaFilter.from_params(terms: [ "Neutro libro" ])
      assert_includes filter.libri, @neutro
      assert_not_includes filter.libri, @campionario
    end

    test "summary compone terms, stati ed editori" do
      filter = GiacenzaFilter.from_params(terms: [ "atlante" ], stati: [ "campionario" ],
                                          editori: [ "Mondadori" ])
      assert_equal "\"atlante\", In campionario e Mondadori", filter.summary
    end

    test "summary con più stati li elenca" do
      filter = GiacenzaFilter.from_params(stati: [ "adottati", "venduti" ])
      assert_equal "Adottati e Venduti", filter.summary
    end

    test "summary include l'anno solo se diverso da quello corrente" do
      corrente = GiacenzaFilter.from_params({})
      assert_not_includes corrente.summary, "anno"

      scorso = GiacenzaFilter.from_params(anno: 1.year.ago.year)
      assert_includes scorso.summary, "anno #{1.year.ago.year}"
    end

    test "params_digest stabile con anno di default esplicito o omesso" do
      digest_a = GiacenzaFilter.from_params(anno: Date.current.year.to_s).params_digest
      digest_b = GiacenzaFilter.from_params({}).params_digest
      assert_equal digest_a, digest_b
    end

    private

      def crea_libro(titolo, editore:)
        Libro.create!(account: @fizzy, user: @user, titolo: titolo,
                      codice_isbn: "TEST-#{SecureRandom.hex(4)}",
                      prezzo_in_cents: 10000, editore: editore,
                      categoria: categorie(:ministeriali))
      end

      def crea_documento(causale, libro:, quantita:, data: Date.today, sconto: 0.0)
        documento = Documento.create!(account: @fizzy, user: @user, causale: causale,
                                      clientable: @cliente, numero_documento: prossimo_numero,
                                      data_documento: data)
        riga = Riga.create!(libro: libro, quantita: quantita, prezzo_cents: 10000, sconto: sconto)
        documento.documento_righe.create!(riga: riga)
        documento
      end

      def prossimo_numero
        @numero = (@numero || 5000) + 1
      end
  end
end
