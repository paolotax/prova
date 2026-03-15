# frozen_string_literal: true

require "test_helper"

class Appunti::AppuntoCreatorTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :scuole, :classi, :persone, :appunti

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  # 1. Basic creation
  test "creates a drafted appunto with nome and content" do
    creator = Appunti::AppuntoCreator.new(nome: "Test appunto", content: "Some content")
    result = creator.create

    assert result.persisted?
    assert_equal "Test appunto", result.nome
    assert_equal "drafted", result.status
    assert_equal @account, result.account
    assert_equal @user, result.user
  end

  # 2. Always creates new appunto
  test "creates new appunto every time" do
    creator = Appunti::AppuntoCreator.new(nome: "Test", content: "Content")

    assert_difference "Appunto.count", 2 do
      creator.create
      Appunti::AppuntoCreator.new(nome: "Test", content: "Content").create
    end
  end

  # 3. Publish when publish: true
  test "publishes appunto when publish is true" do
    creator = Appunti::AppuntoCreator.new(nome: "Published", content: "Content", publish: true)
    result = creator.create

    assert result.persisted?
    assert_equal "published", result.status
  end

  # 4. Keeps drafted when publish: false
  test "keeps appunto drafted when publish is false" do
    creator = Appunti::AppuntoCreator.new(nome: "Drafted", content: "Content", publish: false)
    result = creator.create

    assert result.persisted?
    assert_equal "drafted", result.status
  end

  # 5. Sets appuntabile from explicit appuntabile_value (Scuola)
  test "sets appuntabile from explicit appuntabile_value with Scuola" do
    scuola = scuole(:scuola_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      appuntabile_value: "Scuola:#{scuola.id}"
    )
    result = creator.create

    assert result.persisted?
    assert_equal scuola, result.appuntabile
  end

  # 5b. Sets appuntabile from explicit appuntabile_value (Classe)
  test "sets appuntabile from explicit appuntabile_value with Classe" do
    classe = classi(:prima_a_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      appuntabile_value: "Classe:#{classe.id}"
    )
    result = creator.create

    assert result.persisted?
    assert_equal classe, result.appuntabile
  end

  # 5c. Sets appuntabile from explicit appuntabile_value (Persona)
  test "sets appuntabile from explicit appuntabile_value with Persona" do
    persona = persone(:persona_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      appuntabile_value: "Persona:#{persona.id}"
    )
    result = creator.create

    assert result.persisted?
    assert_equal persona, result.appuntabile
  end

  # 6. Find existing persona by cellulare
  test "finds existing persona by cellulare" do
    existing = persone(:persona_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cellulare: existing.cellulare
    )

    assert_no_difference "Persona.count" do
      creator.create
    end

    assert_equal existing, creator.persona
  end

  # 6b. Find existing persona by telefono field
  test "finds existing persona when cellulare matches telefono field" do
    existing = persone(:persona_fizzy)
    existing.update!(telefono: "3330001111", cellulare: nil)

    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cellulare: "3330001111"
    )

    assert_no_difference "Persona.count" do
      creator.create
    end

    assert_equal existing, creator.persona
  end

  # 7. Creates new persona when cellulare not found
  test "creates new persona when cellulare not found" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_nome: "Giulia",
      persona_cognome: "Neri",
      persona_cellulare: "3339999999",
      persona_email: "giulia@example.com"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    persona = creator.persona
    assert_equal "Giulia", persona.nome
    assert_equal "Neri", persona.cognome
    assert_equal "3339999999", persona.cellulare
    assert_equal "giulia@example.com", persona.email
    assert_equal @account, persona.account
  end

  # 8. Creates persona with nome only
  test "creates persona with nome only" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_nome: "Giulia"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    assert_equal "Giulia", creator.persona.nome
    assert_nil creator.persona.cognome
  end

  # 9. Creates persona with cognome only
  test "creates persona with cognome only" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cognome: "Neri"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    assert_equal "Neri", creator.persona.cognome
    assert_nil creator.persona.nome
  end

  # 10. Links persona to scuola by scuola_nome
  test "links new persona to scuola by scuola_nome" do
    scuola = scuole(:scuola_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_nome: "Giulia",
      persona_cognome: "Neri",
      persona_cellulare: "3339999999",
      persona_scuola_nome: "Leonardo"
    )
    creator.create

    assert_equal scuola, creator.persona.scuola
  end

  # 11. When persona exists, appuntabile is always persona
  test "appuntabile is persona even when persona has scuola" do
    existing = persone(:persona_fizzy)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cellulare: existing.cellulare
    )
    result = creator.create

    assert_equal existing, result.appuntabile
  end

  # 12. Falls back to persona as appuntabile when persona has no scuola
  test "falls back to persona as appuntabile when persona has no scuola" do
    existing = persone(:persona_fizzy_no_scuola)
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cellulare: existing.cellulare
    )
    result = creator.create

    assert_equal existing, result.appuntabile
  end

  # 13. Persona is appuntabile, but scuola from combobox is linked to persona
  test "persona is appuntabile and linked to scuola from appuntabile_value" do
    existing = persone(:persona_fizzy_no_scuola)
    scuola = scuole(:scuola_fizzy_nord)

    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      persona_cellulare: existing.cellulare,
      appuntabile_value: "Scuola:#{scuola.id}"
    )
    result = creator.create

    assert_equal existing, result.appuntabile
    existing.reload
    assert_equal scuola, existing.scuola
  end

  # 14. Passes telefono and email to appunto
  test "passes telefono and email to appunto" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Test",
      telefono: "0211234567",
      email: "test@example.com"
    )
    result = creator.create

    assert_equal "0211234567", result.telefono
    assert_equal "test@example.com", result.email
  end
end
