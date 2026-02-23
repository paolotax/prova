require "test_helper"

class Accounts::MandatoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :editori, :mandati, :scuole

  setup do
    @fizzy = accounts(:fizzy)
    @acme = accounts(:acme)
    Current.account = @fizzy
  end

  teardown do
    Current.account = nil
  end

  test "validates editore uniqueness per account scope" do
    existing = mandati(:fizzy_zanichelli)
    mandato = Accounts::Mandato.new(
      account: @fizzy,
      editore: existing.editore,
      provincia: existing.provincia,
      grado: existing.grado,
      anno_scolastico: existing.anno_scolastico
    )
    assert_not mandato.valid?
  end

  test "allows same editore for different accounts" do
    mandato = Accounts::Mandato.new(
      account: @acme,
      editore: editori(:mondadori),
      anno_scolastico: "2025/2026"
    )
    assert mandato.valid?
  end

  test "allows same editore with different provincia" do
    mandato = Accounts::Mandato.new(
      account: @fizzy,
      editore: editori(:zanichelli),
      provincia: "TO",
      anno_scolastico: "2025/2026"
    )
    assert mandato.valid?
  end

  test "copre_scuola? with nil provincia and grado covers all" do
    mandato = mandati(:fizzy_zanichelli)
    scuola = scuole(:scuola_fizzy)
    assert mandato.copre_scuola?(scuola)
  end

  test "copre_scuola? with matching provincia" do
    mandato = mandati(:acme_zanichelli)
    scuola = scuole(:scuola_acme)
    assert mandato.copre_scuola?(scuola)
  end

  test "copre_scuola? with non-matching provincia" do
    mandato = mandati(:acme_zanichelli) # provincia: "RM"
    scuola = scuole(:scuola_fizzy) # provincia: "MI"
    assert_not mandato.copre_scuola?(scuola)
  end

  test "copre_scuola? with non-matching grado" do
    mandato = mandati(:acme_zanichelli) # grado: "N"
    scuola = scuole(:scuola_fizzy) # grado: "E"
    assert_not mandato.copre_scuola?(scuola)
  end

  test "account association" do
    mandato = mandati(:fizzy_zanichelli)
    assert_equal @fizzy, mandato.account
  end

  test "editore association" do
    mandato = mandati(:fizzy_zanichelli)
    assert_equal editori(:zanichelli), mandato.editore
  end
end
