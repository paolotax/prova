# frozen_string_literal: true

require "test_helper"

class LibroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :categorie

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "candidati_prosegui infersce il volume successivo per titolo-base e categoria, con eccezione LIBRO DELLA PRIMA -> SUSSIDIARIO" do
    l1 = crea_libro(titolo: "Banda Bus 1", classe: 1, disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    l2 = crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    # stessa disciplina di destinazione ma titolo-base diverso: escluso
    crea_libro(titolo: "Altro Libro 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    # stesso titolo-base ma categoria diversa: escluso
    crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)",
               categoria: categorie(:parascolastico))

    assert_equal [l2], l1.candidati_prosegui

    l1.update!(prosegue_in: l2)
    assert_equal l2, l1.reload.prosegue_in
    assert_equal l1, l2.reload.precedente
  end

  test "candidati_prosegui segue la stessa disciplina quando non e' primo biennio" do
    fonte = crea_libro(titolo: "Sussidiario Blu 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    match = crea_libro(titolo: "Sussidiario Blu 3", classe: 3, disciplina: "SUSSIDIARIO (1° BIENNIO)")

    assert_equal [match], fonte.candidati_prosegui
  end

  test "candidati_prosegui filtra per disciplina: stesso titolo-base ma disciplina diversa escluso" do
    fonte = crea_libro(titolo: "Sussidiario Blu 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    crea_libro(titolo: "Sussidiario Blu 3", classe: 3, disciplina: "LINGUA INGLESE")

    assert_empty fonte.candidati_prosegui
  end

  test "candidati_prosegui senza disciplina sulla fonte matcha su categoria+classe+titolo-base" do
    fonte = crea_libro(titolo: "Geo Lab 2", classe: 2, disciplina: nil)
    match = crea_libro(titolo: "Geo Lab 3", classe: 3, disciplina: "LINGUA INGLESE")

    assert_equal [match], fonte.candidati_prosegui
  end

  test "titolo_base rimuove il numero di volume in coda" do
    assert_equal "BANDA BUS",   crea_libro(titolo: "BANDA BUS 1", classe: 1).titolo_base
    assert_equal "SUSSIDIARIO", crea_libro(titolo: "Sussidiario Vol. 2", classe: 2).titolo_base
    assert_equal "GEO LAB",     crea_libro(titolo: "GEO LAB", classe: 3).titolo_base
  end

  private

  def crea_libro(titolo:, classe: nil, disciplina: nil, categoria: nil)
    Libro.create!(
      account: @account,
      user: @user,
      categoria: categoria || categorie(:ministeriali),
      titolo: titolo,
      classe: classe,
      disciplina: disciplina,
      codice_isbn: SecureRandom.hex(6),
      prezzo_in_cents: 1000
    )
  end
end
