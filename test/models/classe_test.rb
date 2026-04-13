require "test_helper"

class ClasseTest < ActiveSupport::TestCase
  fixtures :classi, :scuole, :accounts

  test "tappa_target delegates to scuola" do
    classe = classi(:prima_a_fizzy)
    assert_equal classe.scuola, classe.tappa_target
  end

  test "default_titolo_tappa references the sezione" do
    classe = classi(:prima_a_fizzy)
    assert_match(/Classe/, classe.default_titolo_tappa)
  end
end
