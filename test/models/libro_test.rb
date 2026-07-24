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

  test "prosegue_in collega il volume successivo e candidati_prosegui li inferisce da collana+classe" do
    l1 = crea_libro(titolo: "Banda Bus 1", collana: "Banda Bus", classe: 1)
    l2 = crea_libro(titolo: "Banda Bus 2", collana: "Banda Bus", classe: 2)

    assert_includes l1.candidati_prosegui, l2

    l1.update!(prosegue_in: l2)
    assert_equal l2, l1.reload.prosegue_in
    assert_equal l1, l2.reload.precedente
  end

  private

  def crea_libro(titolo:, collana: nil, classe: nil, disciplina: nil)
    Libro.create!(
      account: @account,
      user: @user,
      categoria: categorie(:ministeriali),
      titolo: titolo,
      collana: collana,
      classe: classe,
      disciplina: disciplina,
      codice_isbn: SecureRandom.hex(6),
      prezzo_in_cents: 1000
    )
  end
end
