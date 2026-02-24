require "test_helper"

class ScuolaTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  test "plessi inherit area from direzione on save" do
    direzione = scuole(:scuola_fizzy)
    plesso = Scuola.create!(
      account: accounts(:fizzy),
      denominazione: "Plesso Test",
      direzione: direzione,
      provincia: "MI",
      grado: "E"
    )

    direzione.update!(area: "Nord")
    plesso.reload

    assert_equal "Nord", plesso.area
  end
end
