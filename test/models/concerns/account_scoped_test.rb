# test/models/concerns/account_scoped_test.rb
require "test_helper"

class AccountScopedTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :libri,
           :causali, :categorie, :editori

  setup do
    @fizzy = accounts(:fizzy)
    @acme = accounts(:acme)
    @user = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  # Test with Documento model
  test "documento requires account_id" do
    Current.account = nil
    documento = Documento.new(
      user: @user,
      causale: causali(:vendita),
      numero_documento: 999,
      data_documento: Date.today
    )

    assert_not documento.valid?
    assert documento.errors[:account_id].any?
  end

  test "documento sets account from Current on create" do
    documento = Documento.new(
      user: @user,
      causale: causali(:vendita),
      numero_documento: 999,
      data_documento: Date.today
    )
    documento.valid? # triggers before_validation callback

    assert_equal @fizzy, documento.account
  end

  test "documento for_account scope filters by account" do
    fizzy_docs = Documento.for_account(@fizzy)
    acme_docs = Documento.for_account(@acme)

    assert fizzy_docs.all? { |d| d.account_id == @fizzy.id }
    assert acme_docs.all? { |d| d.account_id == @acme.id }
    assert_not_equal fizzy_docs.pluck(:id), acme_docs.pluck(:id)
  end

  # Test with Cliente model
  test "cliente requires account_id" do
    Current.account = nil
    cliente = Cliente.new(
      user: @user,
      denominazione: "Test Cliente"
    )

    assert_not cliente.valid?
    assert cliente.errors[:account_id].any?
  end

  test "cliente sets account from Current on create" do
    cliente = Cliente.new(
      user: @user,
      denominazione: "Test Cliente"
    )
    cliente.valid? # triggers before_validation callback

    assert_equal @fizzy, cliente.account
  end

  test "cliente for_account scope filters by account" do
    fizzy_clients = Cliente.for_account(@fizzy)
    acme_clients = Cliente.for_account(@acme)

    assert fizzy_clients.all? { |c| c.account_id == @fizzy.id }
    assert acme_clients.all? { |c| c.account_id == @acme.id }
  end

  # Test with Libro model
  test "libro requires account_id" do
    Current.account = nil
    libro = Libro.new(
      user: @user,
      categoria: categorie(:scolastica),
      titolo: "Test Libro"
    )

    assert_not libro.valid?
    assert libro.errors[:account_id].any?
  end

  test "libro sets account from Current on create" do
    libro = Libro.new(
      user: @user,
      categoria: categorie(:scolastica),
      titolo: "Test Libro"
    )
    libro.valid? # triggers before_validation callback

    assert_equal @fizzy, libro.account
  end

  test "libro for_account scope filters by account" do
    fizzy_books = Libro.for_account(@fizzy)
    acme_books = Libro.for_account(@acme)

    assert fizzy_books.all? { |l| l.account_id == @fizzy.id }
    assert acme_books.all? { |l| l.account_id == @acme.id }
  end

  # Test data isolation
  test "accounts have isolated data" do
    assert_equal 1, @fizzy.documenti.count
    assert_equal 1, @acme.documenti.count

    assert_equal 1, @fizzy.clienti.count
    assert_equal 1, @acme.clienti.count

    assert_equal 1, @fizzy.libri.count
    assert_equal 1, @acme.libri.count

    # Ensure they are different records
    assert_not_equal @fizzy.documenti.first.id, @acme.documenti.first.id
    assert_not_equal @fizzy.clienti.first.id, @acme.clienti.first.id
    assert_not_equal @fizzy.libri.first.id, @acme.libri.first.id
  end
end
