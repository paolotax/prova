require "test_helper"

class Clienti::ImporterTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :clienti

  setup do
    Current.user = users(:one)
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.reset
  end

  test "creates cliente with fuzzy input" do
    result = Clienti::Importer.new(
      nome: "Libreria Roma Srl",
      piva: "  001122334-45 ",
      citta: "Roma",
      sdi: "ABCDEFG",
      email: "INFO@Libreria.IT"
    ).import

    assert result.ok?, "Expected ok? but got error: #{result.error}"
    assert_equal "created", result.action
    assert_equal "Libreria Roma Srl", result.cliente.denominazione
    assert_equal "00112233445", result.cliente.partita_iva
    assert_equal "Roma", result.cliente.comune
    assert_equal "ABCDEFG", result.cliente.indirizzo_telematico
    assert_equal "info@libreria.it", result.cliente.email
  end

  test "creates cliente with rigid input" do
    result = Clienti::Importer.new(
      denominazione: "Cartolibreria Milano Srl",
      partita_iva: "55667788990",
      comune: "Milano",
      indirizzo: "Via Roma",
      numero_civico: "10",
      cap: "20100",
      provincia: "MI"
    ).import

    assert result.ok?
    assert_equal "created", result.action
    assert_equal "Cartolibreria Milano Srl", result.cliente.denominazione
    assert_equal "55667788990", result.cliente.partita_iva
    assert_equal "Milano", result.cliente.comune
    assert_equal "Via Roma", result.cliente.indirizzo
    assert_equal "10", result.cliente.numero_civico
    assert_equal "20100", result.cliente.cap
    assert_equal "MI", result.cliente.provincia
  end

  test "updates existing cliente by partita_iva with on_conflict update" do
    existing = clienti(:cliente_fizzy)

    result = Clienti::Importer.new(
      denominazione: "Cliente Fizzy Aggiornato",
      partita_iva: existing.partita_iva,
      comune: "Firenze"
    ).import

    assert result.ok?
    assert_equal "updated", result.action
    assert_equal existing.id, result.cliente.id
    assert_equal "Cliente Fizzy Aggiornato", result.cliente.reload.denominazione
    assert_equal "Firenze", result.cliente.comune
  end

  test "skips existing cliente when on_conflict skip" do
    existing = clienti(:cliente_fizzy)
    original_denominazione = existing.denominazione

    result = Clienti::Importer.new(
      denominazione: "Nome Diverso",
      partita_iva: existing.partita_iva,
      on_conflict: "skip"
    ).import

    assert result.ok?
    assert_equal "skipped", result.action
    assert_equal original_denominazione, existing.reload.denominazione
  end

  test "deduplicates by codice_fiscale when no partita_iva" do
    existing = clienti(:cliente_fizzy)
    existing.update!(codice_fiscale: "RSSMRA85M01H501Z", partita_iva: nil)

    result = Clienti::Importer.new(
      denominazione: "Aggiornato via CF",
      cf: " rssmra85m01h501z "
    ).import

    assert result.ok?
    assert_equal "updated", result.action
    assert_equal existing.id, result.cliente.id
    assert_equal "RSSMRA85M01H501Z", result.cliente.codice_fiscale
  end

  test "fails without denominazione or nome" do
    result = Clienti::Importer.new(
      partita_iva: "11111111111",
      comune: "Roma"
    ).import

    assert_not result.ok?
    assert_match(/denominazione/i, result.error)
  end

  test "import_batch creates multiple clienti" do
    items = [
      { nome: "Batch Cliente 1", piva: "11111111111", citta: "Roma" },
      { nome: "Batch Cliente 2", piva: "22222222222", citta: "Milano" }
    ]

    result = Clienti::Importer.import_batch(items)

    assert_equal 2, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 0, result[:skipped]
    assert_empty result[:errors]
  end

  test "import_batch with on_conflict skip" do
    existing = clienti(:cliente_fizzy)
    items = [
      { denominazione: "Skip Questo", partita_iva: existing.partita_iva },
      { nome: "Crea Questo", piva: "33333333333", citta: "Napoli" }
    ]

    result = Clienti::Importer.import_batch(items, on_conflict: "skip")

    assert_equal 1, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 1, result[:skipped]
    assert_empty result[:errors]
  end

  test "maps ragione_sociale to denominazione" do
    result = Clienti::Importer.new(
      ragione_sociale: "Test Ragione Sociale",
      piva: "44444444444"
    ).import

    assert result.ok?
    assert_equal "Test Ragione Sociale", result.cliente.denominazione
  end

  test "maps nome_persona and cognome correctly" do
    result = Clienti::Importer.new(
      denominazione: "Rossi Mario Cartolibreria",
      cognome: "Rossi",
      nome_persona: "Mario",
      piva: "55555555555"
    ).import

    assert result.ok?
    assert_equal "Rossi", result.cliente.cognome
    assert_equal "Mario", result.cliente.nome
  end

  test "downcases pec" do
    result = Clienti::Importer.new(
      denominazione: "Test PEC",
      piva: "66666666666",
      pec: "INFO@PEC.IT"
    ).import

    assert result.ok?
    assert_equal "info@pec.it", result.cliente.pec
  end

  test "new clienti get current user" do
    result = Clienti::Importer.new(
      denominazione: "Test User Assignment",
      piva: "77777777777"
    ).import

    assert result.ok?
    assert_equal Current.user, result.cliente.user
  end
end
