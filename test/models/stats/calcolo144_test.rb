require "test_helper"

class Stats::Calcolo144Test < ActiveSupport::TestCase
  fixtures :prezzi_ministeriali

  setup do
    Stats::Calcolo144.reset!
  end

  test "discipline_144 loads from prezzi_ministeriali" do
    disc = Stats::Calcolo144.discipline_144
    assert disc.is_a?(Hash)
    assert disc.key?("IL LIBRO DELLA PRIMA CLASSE")
    assert disc.key?("SUSSIDIARIO DEI LINGUAGGI")
    assert disc.key?("SUSSIDIARIO DELLE DISCIPLINE")
    assert disc.key?("SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)")
    assert disc.key?("SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)")
  end

  test "fascicoli have peso 0.5" do
    disc = Stats::Calcolo144.discipline_144
    assert_equal 0.5, disc["SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)"][:peso]
    assert_equal 0.5, disc["SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)"][:peso]
  end

  test "non-fascicoli have peso 1.0" do
    disc = Stats::Calcolo144.discipline_144
    assert_equal 1.0, disc["IL LIBRO DELLA PRIMA CLASSE"][:peso]
    assert_equal 1.0, disc["SUSSIDIARIO DEI LINGUAGGI"][:peso]
    assert_equal 1.0, disc["SUSSIDIARIO DELLE DISCIPLINE"][:peso]
  end

  test "does not include RELIGIONE or LINGUA INGLESE" do
    disc = Stats::Calcolo144.discipline_144
    refute disc.key?("RELIGIONE")
    refute disc.key?("LINGUA INGLESE")
  end

  test "discipline_names returns array" do
    names = Stats::Calcolo144.discipline_names
    assert names.is_a?(Array)
    assert_equal 5, names.size
    assert_includes names, "IL LIBRO DELLA PRIMA CLASSE"
  end

  test "peso_for returns correct weight" do
    assert_equal 1.0, Stats::Calcolo144.peso_for("IL LIBRO DELLA PRIMA CLASSE")
    assert_equal 0.5, Stats::Calcolo144.peso_for("SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)")
    assert_equal 0, Stats::Calcolo144.peso_for("LINGUA INGLESE")
  end

  test "peso_case_sql generates valid SQL" do
    sql = Stats::Calcolo144.peso_case_sql("my_col")
    assert_includes sql, "CASE"
    assert_includes sql, "IL LIBRO DELLA PRIMA CLASSE"
    assert_includes sql, "0.5"
    assert_includes sql, "ELSE 0"
  end

  test "each discipline has prezzo_cents" do
    Stats::Calcolo144.discipline_144.each do |name, info|
      assert info[:prezzo_cents].present?, "#{name} should have prezzo_cents"
      assert info[:prezzo_cents] > 0
    end
  end
end
