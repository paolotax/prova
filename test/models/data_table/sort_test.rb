require "test_helper"

class DataTable::SortTest < ActiveSupport::TestCase
  class TestColumns < DataTable::Columns
    self.prefix = "widgets"

    column :nome,   label: "Nome",   width: "10rem", sort: "widgets.nome"
    column :comune, label: "Comune", width: "8rem",  sort: "widgets.comune"
    column :libero, label: "Libero", width: "6rem" # non sortabile
  end

  def sort_for(param, keys: %w[ nome comune libero ])
    DataTable::Sort.new(param, columns: TestColumns.visible(keys))
  end

  test "parse di sort multiplo mantiene l'ordine del param" do
    sort = sort_for("comune.asc,nome.desc")
    assert_equal [ [ :comune, "asc" ], [ :nome, "desc" ] ], sort.entries
    assert sort.active?
    assert sort.multi?
  end

  test "ignora chiavi sconosciute, non sortabili e direzioni invalide" do
    assert_equal [ [ :nome, "asc" ] ], sort_for("nome.asc,boh.asc,libero.asc,comune.up").entries
  end

  test "ignora colonne sortabili ma non visibili" do
    assert_empty sort_for("comune.asc", keys: %w[ nome ]).entries
  end

  test "param vuoto o nil non è attivo" do
    assert_not sort_for(nil).active?
    assert_not sort_for("").active?
  end

  test "deduplica la stessa chiave tenendo la prima" do
    assert_equal [ [ :nome, "desc" ] ], sort_for("nome.desc,nome.asc").entries
  end

  test "order_clauses usa il frammento sql della colonna con NULLS LAST" do
    clauses = sort_for("comune.asc,nome.desc").order_clauses.map(&:to_s)
    assert_equal [ "widgets.comune ASC NULLS LAST", "widgets.nome DESC NULLS LAST" ], clauses
  end

  test "direction_for e position_for" do
    sort = sort_for("comune.asc,nome.desc")
    assert_equal "asc", sort.direction_for(:comune)
    assert_equal "desc", sort.direction_for("nome")
    assert_nil sort.direction_for(:libero)
    assert_equal 1, sort.position_for(:comune)
    assert_equal 2, sort.position_for(:nome)
    assert_nil sort.position_for(:libero)
  end

  test "to_param round-trip" do
    assert_equal "comune.asc,nome.desc", sort_for("comune.asc,nome.desc").to_param
  end
end
