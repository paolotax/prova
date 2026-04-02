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
    importer = Clienti::Importer.new(
      nome: "Libreria Roma Srl",
      piva: "  001122334-45 ",
      citta: "Roma",
      sdi: "ABCDEFG",
      email: "INFO@Libreria.IT"
    ).import

    assert importer.ok?, "Expected ok? but got error: #{importer.error}"
    assert_equal "created", importer.action

    cliente = Cliente.find(importer.result[:id])
    assert_equal "Libreria Roma Srl", cliente.denominazione
    assert_equal "00112233445", cliente.partita_iva
    assert_equal "Roma", cliente.comune
    assert_equal "ABCDEFG", cliente.indirizzo_telematico
    assert_equal "info@libreria.it", cliente.email
  end

  test "creates cliente with rigid input" do
    importer = Clienti::Importer.new(
      denominazione: "Cartolibreria Milano Srl",
      partita_iva: "55667788990",
      comune: "Milano",
      indirizzo: "Via Roma",
      numero_civico: "10",
      cap: "20100",
      provincia: "MI"
    ).import

    assert importer.ok?
    assert_equal "created", importer.action

    cliente = Cliente.find(importer.result[:id])
    assert_equal "Cartolibreria Milano Srl", cliente.denominazione
    assert_equal "55667788990", cliente.partita_iva
    assert_equal "Milano", cliente.comune
    assert_equal "Via Roma", cliente.indirizzo
    assert_equal "10", cliente.numero_civico
    assert_equal "20100", cliente.cap
    assert_equal "MI", cliente.provincia
  end

  test "updates existing cliente by partita_iva with on_conflict update" do
    existing = clienti(:cliente_fizzy)

    importer = Clienti::Importer.new(
      denominazione: "Cliente Fizzy Aggiornato",
      partita_iva: existing.partita_iva,
      comune: "Firenze"
    ).import

    assert importer.ok?
    assert_equal "updated", importer.action
    assert_equal existing.id, importer.result[:id]
    assert_equal "Cliente Fizzy Aggiornato", existing.reload.denominazione
    assert_equal "Firenze", existing.comune
  end

  test "skips existing cliente when on_conflict skip" do
    existing = clienti(:cliente_fizzy)
    original_denominazione = existing.denominazione

    importer = Clienti::Importer.new(
      denominazione: "Nome Diverso",
      partita_iva: existing.partita_iva,
      on_conflict: "skip"
    ).import

    assert importer.ok?
    assert_equal "skipped", importer.action
    assert_equal original_denominazione, existing.reload.denominazione
  end

  test "deduplicates by codice_fiscale when no partita_iva" do
    existing = clienti(:cliente_fizzy)
    existing.update!(codice_fiscale: "RSSMRA85M01H501Z", partita_iva: nil)

    importer = Clienti::Importer.new(
      denominazione: "Aggiornato via CF",
      cf: " rssmra85m01h501z "
    ).import

    assert importer.ok?
    assert_equal "updated", importer.action
    assert_equal existing.id, importer.result[:id]
    assert_equal "RSSMRA85M01H501Z", existing.reload.codice_fiscale
  end

  test "fails without denominazione or nome" do
    importer = Clienti::Importer.new(
      partita_iva: "11111111111",
      comune: "Roma"
    ).import

    assert_not importer.ok?
    assert_match(/denominazione/i, importer.error)
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
    importer = Clienti::Importer.new(
      ragione_sociale: "Test Ragione Sociale",
      piva: "44444444444"
    ).import

    assert importer.ok?
    cliente = Cliente.find(importer.result[:id])
    assert_equal "Test Ragione Sociale", cliente.denominazione
  end

  test "maps nome_persona and cognome correctly" do
    importer = Clienti::Importer.new(
      denominazione: "Rossi Mario Cartolibreria",
      cognome: "Rossi",
      nome_persona: "Mario",
      piva: "55555555555"
    ).import

    assert importer.ok?
    cliente = Cliente.find(importer.result[:id])
    assert_equal "Rossi", cliente.cognome
    assert_equal "Mario", cliente.nome
  end

  test "downcases pec" do
    importer = Clienti::Importer.new(
      denominazione: "Test PEC",
      piva: "66666666666",
      pec: "INFO@PEC.IT"
    ).import

    assert importer.ok?
    cliente = Cliente.find(importer.result[:id])
    assert_equal "info@pec.it", cliente.pec
  end

  test "new clienti get current user" do
    importer = Clienti::Importer.new(
      denominazione: "Test User Assignment",
      piva: "77777777777"
    ).import

    assert importer.ok?
    cliente = Cliente.find(importer.result[:id])
    assert_equal Current.user, cliente.user
  end
end
