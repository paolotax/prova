require "test_helper"

class PersonaTest < ActiveSupport::TestCase
  fixtures :persone, :scuole, :accounts

  test "tappa_target returns scuola when present" do
    persona = persone(:persona_fizzy)
    assert_equal persona.scuola, persona.tappa_target
  end

  test "tappa_target is nil without scuola" do
    persona = persone(:persona_fizzy_no_scuola)
    assert_nil persona.tappa_target
  end
end
