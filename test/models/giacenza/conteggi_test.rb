require "test_helper"

class Giacenza::ConteggiTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    Current.account = @account
    Current.user = @user

    # Libro dedicato: le fixture righe usano libro_fizzy e inquinerebbero i conteggi
    @libro = Libro.create!(account: @account, user: @user, titolo: "Libro conteggi",
                           codice_isbn: "TEST-CONT-1", prezzo_in_cents: 10000,
                           categoria: categorie(:ministeriali))
  end

  teardown do
    Current.reset
  end

  test "conta le copie campionario rispettando causale e anno" do
    crea_documento(causali(:campionario), quantita: 10)
    crea_documento(causali(:campionario), quantita: 4, data: 1.year.ago.to_date)

    assert_equal 10, conteggi_libro[:campionario]
    assert_equal 4, conteggi_libro(anno: 1.year.ago.year)[:campionario]
  end

  test "le quattro causali finiscono in colonne distinte senza somme incrociate" do
    crea_documento(causali(:campionario), quantita: 10)
    crea_documento(causali(:saggi_100), quantita: 3)
    crea_documento(causali(:saggi_50), quantita: 2)
    crea_documento(causali(:scarico_saggi), quantita: 5)

    conteggi = conteggi_libro
    assert_equal 10, conteggi[:campionario]
    assert_equal 3, conteggi[:saggi_100]
    assert_equal 2, conteggi[:saggi_50]
    assert_equal 5, conteggi[:scarico_saggi]
  end

  test "venduti conta solo le copie consegnate, da_consegnare il residuo" do
    vendita = crea_documento(causali(:fattura), quantita: 6)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 4 })

    conteggi = conteggi_libro
    assert_equal 4, conteggi[:venduti]
    assert_equal 2, conteggi[:da_consegnare]
  end

  test "i documenti figli sono esclusi (righe condivise col padre)" do
    padre = crea_documento(causali(:fattura), quantita: 6)
    figlio = Documento.create!(account: @account, user: @user, causale: causali(:vendita),
                               clientable: @cliente, numero_documento: prossimo_numero,
                               data_documento: Date.today, documento_padre: padre)
    figlio.documento_righe.create!(riga: padre.righe.reload.first)

    assert_equal 6, conteggi_libro[:da_consegnare]
  end

  test "per_libro con filtro libro_ids restituisce solo i libri chiesti" do
    altro_libro = Libro.create!(account: @account, user: @user, titolo: "Altro libro",
                                codice_isbn: "TEST-CONT-2", prezzo_in_cents: 10000,
                                categoria: categorie(:ministeriali))
    crea_documento(causali(:campionario), quantita: 10)
    crea_documento(causali(:campionario), quantita: 7, libro: altro_libro)

    conteggi = Giacenza::Conteggi.new(account: @account, anno: Date.current.year)
    solo_uno = conteggi.per_libro([@libro.id])

    assert_equal [@libro.id], solo_uno.keys
    assert_equal 10, solo_uno[@libro.id][:campionario]
  end

  private

  def conteggi_libro(anno: Date.current.year)
    Giacenza::Conteggi.new(account: @account, anno: anno).per_libro[@libro.id]
  end

  def crea_documento(causale, quantita:, sconto: 0.0, data: Date.today, libro: @libro, clientable: @cliente)
    documento = Documento.create!(account: @account, user: @user, causale: causale,
                                  clientable: clientable, numero_documento: prossimo_numero,
                                  data_documento: data)
    riga = Riga.create!(libro: libro, quantita: quantita, prezzo_cents: 10000, sconto: sconto)
    documento.documento_righe.create!(riga: riga)
    documento
  end

  def prossimo_numero
    @numero = (@numero || 1000) + 1
  end
end
