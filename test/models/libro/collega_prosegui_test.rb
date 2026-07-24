# frozen_string_literal: true

require "test_helper"

class Libro::CollegaProseguiTest < ActiveSupport::TestCase
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

  test "collega solo i match univoci e non tocca i link esistenti" do
    # 1->2 univoco (eccezione primo biennio); il 2 ha due candidati "Banda Bus 3"
    # con stesso titolo-base+disciplina -> ambiguo, non collegato
    l1 = crea_libro(titolo: "Banda Bus 1", classe: 1, disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    l2 = crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    crea_libro(titolo: "Banda Bus 3", classe: 3, disciplina: "SUSSIDIARIO (1° BIENNIO)")
    crea_libro(titolo: "Banda Bus 3", classe: 3, disciplina: "SUSSIDIARIO (1° BIENNIO)")

    n = Libro::CollegaProsegui.new(account: l1.account).call

    assert_equal 1, n
    assert_equal l2, l1.reload.prosegue_in
    assert_nil l2.reload.prosegue_in_id
  end

  test "e idempotente: una seconda call non crea nuovi link" do
    l1 = crea_libro(titolo: "Banda Bus 1", classe: 1, disciplina: "IL LIBRO DELLA PRIMA CLASSE")
    crea_libro(titolo: "Banda Bus 2", classe: 2, disciplina: "SUSSIDIARIO (1° BIENNIO)")

    assert_equal 1, Libro::CollegaProsegui.new(account: @account).call

    prosegue_in_id_prima = l1.reload.prosegue_in_id
    assert_not_nil prosegue_in_id_prima

    assert_equal 0, Libro::CollegaProsegui.new(account: @account).call
    assert_equal prosegue_in_id_prima, l1.reload.prosegue_in_id
  end

  private

  def crea_libro(titolo:, classe: nil, disciplina: nil)
    Libro.create!(
      account: @account,
      user: @user,
      categoria: categorie(:ministeriali),
      titolo: titolo,
      classe: classe,
      disciplina: disciplina,
      codice_isbn: SecureRandom.hex(6),
      prezzo_in_cents: 1000
    )
  end
end
