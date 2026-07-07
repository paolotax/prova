require "test_helper"

class GiacenzaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    Current.account = @account
    Current.user = @user

    # Libro dedicato: le fixture righe usano libro_fizzy e inquinerebbero i conteggi
    @libro = Libro.create!(account: @account, user: @user, titolo: "Libro magazzino",
                           codice_isbn: "TEST-GIAC-1", prezzo_in_cents: 10000,
                           categoria: categorie(:ministeriali))
  end

  teardown do
    Current.reset
  end

  test "carico fornitore carica il disponibile" do
    crea_documento(causali(:carico_fornitore), quantita: 10)

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 0, giacenza.venduto_copie
    assert_equal 0, giacenza.campionario
  end

  test "vendita non consegnata impegna, non scarica" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    crea_documento(causali(:fattura), quantita: 4)

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
    assert_equal 4, giacenza.impegnato
    assert_equal 0, giacenza.venduto_copie
  end

  test "consegna parziale splitta impegnato e venduto" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 3 })

    giacenza = ricalcola
    assert_equal 7, giacenza.disponibile        # 10 - 3 consegnate
    assert_equal 1, giacenza.impegnato          # 4 - 3
    assert_equal 3, giacenza.venduto_copie
    assert_equal 3 * 10000, giacenza.venduto_cents
  end

  test "vendita consegnata scarica e vende" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.mark_consegnato

    giacenza = ricalcola
    assert_equal 6, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 4, giacenza.venduto_copie
    assert_equal 4 * 10000, giacenza.venduto_cents
  end

  test "TD04 consegnata rientra in giacenza e riduce il venduto" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    nota = crea_documento(causali(:nota_credito), quantita: 2)
    nota.mark_consegnato

    giacenza = ricalcola
    assert_equal 12, giacenza.disponibile       # rientro fisico
    assert_equal(-2, giacenza.venduto_copie)
    assert_equal(-2 * 10000, giacenza.venduto_cents)
  end

  test "lo sconto valorizza il venduto al prezzo scontato" do
    vendita = crea_documento(causali(:fattura), quantita: 2, sconto: 20.0)
    vendita.mark_consegnato

    giacenza = ricalcola
    assert_equal 2 * 8000, giacenza.venduto_cents   # 10000 - 20%
  end

  test "il campionario si muove senza gating di consegna" do
    crea_documento(causali(:scarico_saggi), quantita: 5)

    giacenza = ricalcola
    assert_equal(-5, giacenza.campionario)
    assert_equal 0, giacenza.disponibile
  end

  test "gli ordini (tipo_movimento ordine) non muovono nulla" do
    crea_documento(causali(:ordine), quantita: 7)

    giacenza = ricalcola
    assert_equal 0, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 0, giacenza.campionario
  end

  test "il documento figlio non conta (righe condivise col padre)" do
    padre = crea_documento(causali(:fattura), quantita: 4)
    figlio = Documento.create!(account: @account, user: @user, causale: causali(:vendita),
                               clientable: @cliente, numero_documento: prossimo_numero,
                               data_documento: Date.today, documento_padre: padre)
    figlio.documento_righe.create!(riga: padre.righe.reload.first)

    giacenza = ricalcola
    assert_equal 4, giacenza.impegnato
  end

  test "i documenti di altri account sono esclusi" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    Documento.create!(account: accounts(:acme), user: users(:multi_account),
                      causale: causali(:carico_fornitore), clientable: clienti(:cliente_acme),
                      numero_documento: prossimo_numero, data_documento: Date.today)
      .documento_righe.create!(riga: Riga.create!(libro: @libro, quantita: 99, prezzo_cents: 10000))

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
  end

  test "ricalcola_tutte! coincide col ricalcolo per libro" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 3 })

    per_libro = ricalcola.attributes.slice("disponibile", "campionario", "impegnato", "venduto_copie", "venduto_cents")
    Giacenza.delete_all

    Giacenza.ricalcola_tutte!(@account)
    bulk = Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id)
      .attributes.slice("disponibile", "campionario", "impegnato", "venduto_copie", "venduto_cents")

    assert_equal per_libro, bulk
  end

  test "creare e distruggere una documento_riga ricalcola la giacenza" do
    doc = crea_documento(causali(:carico_fornitore), quantita: 10)
    assert_equal 10, Giacenza.find_by!(libro_id: @libro.id).disponibile

    doc.documento_righe.reload.first.destroy
    assert_equal 0, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "aggiornare la quantita di una riga ricalcola la giacenza" do
    doc = crea_documento(causali(:carico_fornitore), quantita: 10)
    doc.righe.reload.first.update!(quantita: 25)

    assert_equal 25, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "la consegna ricalcola la giacenza dei libri del documento" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.mark_consegnato

    giacenza = Giacenza.find_by!(libro_id: @libro.id)
    assert_equal 6, giacenza.disponibile
    assert_equal 4, giacenza.venduto_copie
  end

  test "distruggere un documento ricalcola la giacenza" do
    doc = crea_documento(causali(:carico_fornitore), quantita: 10)
    doc.destroy!

    assert_equal 0, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "sospendi_ricalcolo salta i trigger per-riga" do
    Giacenza.sospendi_ricalcolo do
      crea_documento(causali(:carico_fornitore), quantita: 10)
    end
    assert_nil Giacenza.find_by(libro_id: @libro.id)

    Giacenza.ricalcola_tutte!(@account)
    assert_equal 10, Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id).disponibile
  end

  private

  def crea_documento(causale, quantita:, sconto: 0.0, clientable: @cliente)
    documento = Documento.create!(account: @account, user: @user, causale: causale,
                                  clientable: clientable, numero_documento: prossimo_numero,
                                  data_documento: Date.today)
    riga = Riga.create!(libro: @libro, quantita: quantita, prezzo_cents: 10000, sconto: sconto)
    documento.documento_righe.create!(riga: riga)
    documento
  end

  def prossimo_numero
    @numero = (@numero || 1000) + 1
  end

  def ricalcola
    @libro.ricalcola_giacenza!
    Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id)
  end
end
