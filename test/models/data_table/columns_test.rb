require "test_helper"

class DataTable::ColumnsTest < ActiveSupport::TestCase
  class TestColumns < DataTable::Columns
    self.prefix = "widgets"

    column :nome,   label: "Nome",   width: "10rem", sort: "widgets.nome"
    column :comune, label: "Comune", width: "8rem",  sort: "widgets.comune"
    column :extra,  label: "Extra",  width: "6rem",  default: false,
           scope: ->(s) { s + [ :extra_scope ] }
  end

  test "defaults esclude le colonne con default: false" do
    assert_equal %i[ nome comune ], TestColumns.defaults.map(&:key)
  end

  test "visible filtra e ordina secondo il registro" do
    assert_equal %i[ nome extra ], TestColumns.visible([ "extra", "nome" ]).map(&:key)
  end

  test "visible ignora chiavi sconosciute e ricade sui default" do
    assert_equal %i[ nome comune ], TestColumns.visible([ "boh" ]).map(&:key)
    assert_equal %i[ nome comune ], TestColumns.visible([]).map(&:key)
    assert_equal %i[ nome comune ], TestColumns.visible(nil).map(&:key)
  end

  test "partial derivato dal prefix" do
    assert_equal "widgets/table/cells/nome", TestColumns.find(:nome).partial
  end

  test "apply_scopes applica solo le scope delle colonne visibili" do
    result = TestColumns.apply_scopes([], TestColumns.visible([ "nome", "extra" ]))
    assert_equal [ :extra_scope ], result
  end

  test "grid_template include checkbox e ingranaggio" do
    assert_equal "2.25rem 10rem 8rem 2.5rem", TestColumns.grid_template(TestColumns.defaults)
  end

  test "i registri di classi diverse restano separati" do
    other = Class.new(DataTable::Columns) do
      self.prefix = "altri"
      column :solo, label: "Solo", width: "1rem"
    end

    assert_equal %i[ solo ], other.columns.map(&:key)
    assert_equal %i[ nome comune extra ], TestColumns.columns.map(&:key)
  end
end
