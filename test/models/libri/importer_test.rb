require "test_helper"

class Libri::ImporterTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri

  setup do
    Current.user = users(:one)
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.reset
  end

  test "creates libro with fuzzy input" do
    result = Libri::Importer.new(
      isbn: "978-88-000-9999-9",
      titolo: "Nuovo Libro Fuzzy",
      prezzo: "12.50",
      editore: "Mondadori"
    ).import

    assert result.ok?, "Expected ok? but got error: #{result.error}"
    assert_equal "created", result.action
    assert_equal "9788800099999", result.libro.codice_isbn
    assert_equal 1250, result.libro.prezzo_in_cents
    assert_equal editori(:mondadori), result.libro.editore
  end

  test "creates libro with rigid input" do
    result = Libri::Importer.new(
      codice_isbn: "9788800099998",
      titolo: "Nuovo Libro Rigid",
      prezzo_in_cents: 2000,
      editore_id: editori(:zanichelli).id
    ).import

    assert result.ok?
    assert_equal "created", result.action
    assert_equal "9788800099998", result.libro.codice_isbn
    assert_equal 2000, result.libro.prezzo_in_cents
    assert_equal editori(:zanichelli), result.libro.editore
  end

  test "assigns default categoria when not specified" do
    result = Libri::Importer.new(
      isbn: "9788800099997",
      titolo: "Libro Senza Categoria",
      prezzo: "10.00"
    ).import

    assert result.ok?
    assert_equal "non classificato", result.libro.categoria.nome_categoria
  end

  test "assigns specified categoria" do
    result = Libri::Importer.new(
      isbn: "9788800099996",
      titolo: "Libro Con Categoria",
      prezzo: "10.00",
      categoria: "ministeriali"
    ).import

    assert result.ok?
    assert_equal "ministeriali", result.libro.categoria.nome_categoria
  end

  test "creates editore if not found by name" do
    assert_difference "Editore.count", 1 do
      result = Libri::Importer.new(
        isbn: "9788800099995",
        titolo: "Libro Editore Nuovo",
        prezzo: "15.00",
        editore: "Nuova Casa Editrice"
      ).import

      assert result.ok?
      assert_equal "Nuova Casa Editrice", result.libro.editore.editore
    end
  end

  test "updates existing libro by isbn with on_conflict update" do
    existing = libri(:libro_fizzy)

    result = Libri::Importer.new(
      isbn: existing.codice_isbn,
      titolo: "Titolo Aggiornato",
      prezzo: "25.00"
    ).import

    assert result.ok?
    assert_equal "updated", result.action
    assert_equal existing.id, result.libro.id
    assert_equal "Titolo Aggiornato", result.libro.reload.titolo
    assert_equal 2500, result.libro.prezzo_in_cents
  end

  test "skips existing libro when on_conflict skip" do
    existing = libri(:libro_fizzy)
    original_titolo = existing.titolo

    result = Libri::Importer.new(
      isbn: existing.codice_isbn,
      titolo: "Titolo Diverso",
      prezzo: "99.00",
      on_conflict: "skip"
    ).import

    assert result.ok?
    assert_equal "skipped", result.action
    assert_equal original_titolo, existing.reload.titolo
  end

  test "fails without isbn" do
    result = Libri::Importer.new(
      titolo: "Libro Senza ISBN",
      prezzo: "10.00"
    ).import

    assert_not result.ok?
    assert_match(/isbn/i, result.error)
  end

  test "normalizes isbn with spaces and dashes" do
    result = Libri::Importer.new(
      isbn: " 978-88 000-9999 4 ",
      titolo: "ISBN Strano",
      prezzo: "10.00"
    ).import

    assert result.ok?
    assert_equal "9788800099994", result.libro.codice_isbn
  end

  test "normalizes prezzo with comma" do
    result = Libri::Importer.new(
      isbn: "9788800099993",
      titolo: "Prezzo Virgola",
      prezzo: "12,50"
    ).import

    assert result.ok?
    assert_equal 1250, result.libro.prezzo_in_cents
  end

  test "resolves editore_id from numeric string" do
    editore = editori(:pearson)

    result = Libri::Importer.new(
      isbn: "9788800099992",
      titolo: "Editore ID String",
      prezzo: "10.00",
      editore: editore.id.to_s
    ).import

    assert result.ok?
    assert_equal editore, result.libro.editore
  end

  test "import_batch creates multiple libri" do
    items = [
      { isbn: "9788800099991", titolo: "Batch Libro 1", prezzo: "10.00" },
      { isbn: "9788800099990", titolo: "Batch Libro 2", prezzo: "20.00" }
    ]

    result = Libri::Importer.import_batch(items)

    assert_equal 2, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 0, result[:skipped]
    assert_empty result[:errors]
  end

  test "import_batch with on_conflict skip" do
    existing = libri(:libro_fizzy)
    items = [
      { isbn: existing.codice_isbn, titolo: "Skip Questo", prezzo: "10.00" },
      { isbn: "9788800099989", titolo: "Crea Questo", prezzo: "15.00" }
    ]

    result = Libri::Importer.import_batch(items, on_conflict: "skip")

    assert_equal 1, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 1, result[:skipped]
    assert_empty result[:errors]
  end
end
