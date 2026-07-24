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
    # 1->2 univoco; il 2 ha due candidati in classe 3 senza disciplina -> non collegato
    l1 = crea_libro(collana: "Banda Bus", classe: 1)
    l2 = crea_libro(collana: "Banda Bus", classe: 2)
    l3a = crea_libro(collana: "Banda Bus", classe: 3, disciplina: nil)
    l3b = crea_libro(collana: "Banda Bus", classe: 3, disciplina: nil)

    n = Libro::CollegaProsegui.new(account: l1.account).call

    assert_equal 1, n
    assert_equal l2, l1.reload.prosegue_in
    assert_nil l2.reload.prosegue_in_id
  end

  test "e idempotente: una seconda call non crea nuovi link" do
    crea_libro(collana: "Banda Bus", classe: 1)
    crea_libro(collana: "Banda Bus", classe: 2)

    assert_equal 1, Libro::CollegaProsegui.new(account: @account).call

    l1 = Libro.find_by(collana: "Banda Bus", classe: 1)
    prosegue_in_id_prima = l1.reload.prosegue_in_id

    assert_equal 0, Libro::CollegaProsegui.new(account: @account).call
    assert_equal prosegue_in_id_prima, l1.reload.prosegue_in_id
  end

  private

  def crea_libro(titolo: nil, collana: nil, classe: nil, disciplina: nil)
    Libro.create!(
      account: @account,
      user: @user,
      categoria: categorie(:ministeriali),
      titolo: titolo || "#{collana} #{classe}".strip,
      collana: collana,
      classe: classe,
      disciplina: disciplina,
      codice_isbn: SecureRandom.hex(6),
      prezzo_in_cents: 1000
    )
  end
end
