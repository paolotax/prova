require "test_helper"

class Stats::AdozioniQueryTest < ActiveSupport::TestCase
  setup do
    conn = ActiveRecord::Base.connection

    # Create TipoScuola
    conn.execute <<~SQL
      INSERT INTO tipi_scuole (tipo, grado, created_at, updated_at)
      VALUES ('SCUOLA PRIMARIA TEST', 'E', NOW(), NOW())
      ON CONFLICT DO NOTHING
    SQL

    # Create two schools in different provinces
    conn.execute <<~SQL
      INSERT INTO import_scuole ("CODICESCUOLA", "DENOMINAZIONESCUOLA", "PROVINCIA", "REGIONE", "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", created_at, updated_at)
      VALUES
        ('TOEE12345A', 'SCUOLA ELEMENTARE TORINO', 'TO', 'PIEMONTE', 'SCUOLA PRIMARIA TEST', NOW(), NOW()),
        ('MIEE67890B', 'SCUOLA ELEMENTARE MILANO', 'MI', 'LOMBARDIA', 'SCUOLA PRIMARIA TEST', NOW(), NOW())
    SQL

    # TO: 3 classi matematica + MI: 1 classe italiano + 1 excluded
    conn.execute <<~SQL
      INSERT INTO import_adozioni ("CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "DISCIPLINA", "CODICEISBN", "AUTORI", "TITOLO", "EDITORE", "PREZZO", "DAACQUIST", "NUOVAADOZ", "CONSIGLIATO", "COMBINAZIONE", "TIPOGRADOSCUOLA", created_at, updated_at)
      VALUES
        ('TOEE12345A', '1', 'A', 'MATEMATICA', '9788891901001', 'ROSSI MARIO', 'PEPPER 1 STAMPATO', 'PEARSON', '10,50', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW()),
        ('TOEE12345A', '1', 'B', 'MATEMATICA', '9788891901002', 'ROSSI MARIO', 'PEPPER 1 4CARATTERI', 'PEARSON', '12,00', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW()),
        ('TOEE12345A', '3', 'C', 'MATEMATICA', '9788804701003', 'BIANCHI LUCA', 'MONDO MATEMATICA 3', 'MONDADORI', '15,00', 'Si', 'No', 'No', 'TP', 'EE', NOW(), NOW()),
        ('MIEE67890B', '3', 'A', 'ITALIANO', '9788891902001', 'VERDI ANNA', 'LEGGERE E SCRIVERE 3', 'PEARSON', '8,00', 'Si', 'Si', 'No', 'TN', 'EE', NOW(), NOW()),
        ('TOEE12345A', '1', 'A', 'ITALIANO', '9788891909999', 'NERI PAOLO', 'LIBRO ESCLUSO', 'ZANICHELLI', '20,00', 'No', 'No', 'No', 'TP', 'EE', NOW(), NOW())
    SQL
  end

  teardown do
    conn = ActiveRecord::Base.connection
    conn.execute "DELETE FROM import_adozioni WHERE \"CODICESCUOLA\" IN ('TOEE12345A', 'MIEE67890B')"
    conn.execute "DELETE FROM import_scuole WHERE \"CODICESCUOLA\" IN ('TOEE12345A', 'MIEE67890B')"
    conn.execute "DELETE FROM tipi_scuole WHERE tipo = 'SCUOLA PRIMARIA TEST'"
  end

  # 1. Group by editore
  test "group by editore returns classi_count, percentuale, copie_stimate, importo_cents" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["editore"]).call

    assert_equal 4, result[:totals][:classi_count]
    assert_equal 2, result[:totals][:scuole_count]

    editori = result[:results].index_by { |r| r[:editore] }

    # Pearson: 3 classi (TO sezione A, TO sezione B, MI sezione A)
    assert_equal 3, editori["PEARSON"][:classi_count]
    assert_equal 3 * 18, editori["PEARSON"][:copie_stimate]
    assert_in_delta 75.0, editori["PEARSON"][:percentuale], 0.01

    # Mondadori: 1 classe (TO sezione C)
    assert_equal 1, editori["MONDADORI"][:classi_count]
    assert_equal 1 * 18, editori["MONDADORI"][:copie_stimate]
    assert_in_delta 25.0, editori["MONDADORI"][:percentuale], 0.01

    # Zanichelli should NOT appear (DAACQUIST='No')
    assert_nil editori["ZANICHELLI"]
  end

  # 2. Group by disciplina with editore filter
  test "group by disciplina with editore filter" do
    result = Stats::AdozioniQuery.new(
      filters: { editore: "PEARSON" },
      group_by: ["disciplina"]
    ).call

    assert_equal 3, result[:totals][:classi_count]
    disciplines = result[:results].index_by { |r| r[:disciplina] }

    assert_equal 2, disciplines["MATEMATICA"][:classi_count]
    assert_equal 1, disciplines["ITALIANO"][:classi_count]
  end

  # 3. Group by provincia
  test "group by provincia returns all provinces" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["provincia"]).call

    provinces = result[:results].index_by { |r| r[:provincia] }
    assert_equal 3, provinces["TO"][:classi_count]
    assert_equal 1, provinces["MI"][:classi_count]
  end

  # 4. Titolo filter uses ILIKE partial match
  test "titolo filter uses ILIKE partial match" do
    result = Stats::AdozioniQuery.new(
      filters: { titolo: "PEPPER 1" },
      group_by: ["titolo"]
    ).call

    titles = result[:results].map { |r| r[:titolo] }
    assert_includes titles, "PEPPER 1 STAMPATO"
    assert_includes titles, "PEPPER 1 4CARATTERI"
    assert_equal 2, result[:results].size
  end

  # 5. Group by titolo includes isbn, autori, prezzo
  test "group by titolo includes extra columns isbn, autori, prezzo" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["titolo"]).call

    first = result[:results].first
    assert first.key?(:isbn), "Expected :isbn key in result"
    assert first.key?(:autori), "Expected :autori key in result"
    assert first.key?(:prezzo), "Expected :prezzo key in result"
  end

  # 6. Group by scuola includes denominazione, provincia
  test "group by scuola includes extra columns denominazione, provincia" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["scuola"]).call

    schools = result[:results].index_by { |r| r[:scuola] }
    assert_equal "SCUOLA ELEMENTARE TORINO", schools["TOEE12345A"][:denominazione]
    assert_equal "TO", schools["TOEE12345A"][:provincia]
    assert_equal "SCUOLA ELEMENTARE MILANO", schools["MIEE67890B"][:denominazione]
    assert_equal "MI", schools["MIEE67890B"][:provincia]
  end

  # 7. Excludes non-da-acquistare adozioni
  test "excludes DAACQUIST No adozioni" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["editore"]).call

    editori = result[:results].map { |r| r[:editore] }
    refute_includes editori, "ZANICHELLI"
    assert_equal 4, result[:totals][:adozioni_count]
  end

  # 8. Coefficiente changes copie_stimate and importo
  test "coefficiente changes copie_stimate and importo" do
    result_default = Stats::AdozioniQuery.new(filters: {}, group_by: ["editore"], coefficiente: 18).call
    result_custom = Stats::AdozioniQuery.new(filters: {}, group_by: ["editore"], coefficiente: 25).call

    assert_equal 4 * 18, result_default[:totals][:copie_stimate]
    assert_equal 4 * 25, result_custom[:totals][:copie_stimate]

    # importo should scale proportionally
    ratio = result_custom[:totals][:importo_cents].to_f / result_default[:totals][:importo_cents]
    assert_in_delta 25.0 / 18.0, ratio, 0.01
  end

  # 9. Limit restricts results
  test "limit restricts results" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: ["titolo"], limit: 2).call

    assert_equal 2, result[:results].size
  end

  # 10. Multi-dimension group_by
  test "multi-dimension group_by editore + classe" do
    result = Stats::AdozioniQuery.new(filters: {}, group_by: %w[editore classe]).call

    # PEARSON classe 1 (TO A, TO B) = 2 classi
    # PEARSON classe 3 (MI A) = 1 classe
    # MONDADORI classe 3 (TO C) = 1 classe
    combos = result[:results].map { |r| [r[:editore], r[:classe]] }
    assert_includes combos, ["PEARSON", "1"]
    assert_includes combos, ["PEARSON", "3"]
    assert_includes combos, ["MONDADORI", "3"]

    pearson_1 = result[:results].find { |r| r[:editore] == "PEARSON" && r[:classe] == "1" }
    assert_equal 2, pearson_1[:classi_count]
  end

  # 11. Empty results for no matches
  test "empty results for no matches" do
    result = Stats::AdozioniQuery.new(
      filters: { editore: "NONEXISTENT" },
      group_by: ["editore"]
    ).call

    assert_equal 0, result[:totals][:classi_count]
    assert_empty result[:results]
  end

  # 12. solo_144 returns sezioni_144 in totals and results
  test "solo_144 returns sezioni_144 in totals and results" do
    # Insert 144-eligible adozioni (classe 1, SUSSIDIARIO discipline)
    conn = ActiveRecord::Base.connection
    conn.execute <<~SQL
      INSERT INTO import_adozioni ("CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "DISCIPLINA", "CODICEISBN", "AUTORI", "TITOLO", "EDITORE", "PREZZO", "DAACQUIST", "NUOVAADOZ", "CONSIGLIATO", "COMBINAZIONE", "TIPOGRADOSCUOLA", created_at, updated_at)
      VALUES
        ('TOEE12345A', '1', 'A', 'SUSSIDIARIO DEI LINGUAGGI', '9788891901099', 'ROSSI', 'SUSS LING 1', 'PEARSON', '15,00', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW()),
        ('TOEE12345A', '1', 'B', 'SUSSIDIARIO DEI LINGUAGGI', '9788891901098', 'ROSSI', 'SUSS LING 1', 'PEARSON', '15,00', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW()),
        ('MIEE67890B', '1', 'A', 'IL LIBRO DELLA PRIMA CLASSE', '9788891901097', 'VERDI', 'PRIMA CLASSE', 'MONDADORI', '12,00', 'Si', 'Si', 'No', 'TN', 'EE', NOW(), NOW())
    SQL

    query = Stats::AdozioniQuery.new(
      filters: {},
      group_by: ["editore"],
      solo_144: true,
      limit: 5
    )
    result = query.call

    assert result[:totals].key?(:sezioni_144), "totals should have sezioni_144"
    assert result[:results].any?
    result[:results].each do |r|
      assert r.key?(:sezioni_144), "each result should have sezioni_144"
    end

    # SUSSIDIARIO DEI LINGUAGGI has peso 1.0, IL LIBRO DELLA PRIMA CLASSE has peso 1.0
    # PEARSON: 2 adozioni x 1.0 = 2.0, MONDADORI: 1 adozione x 1.0 = 1.0
    assert_in_delta 3.0, result[:totals][:sezioni_144], 0.1
  end

  # 13. without solo_144 does not include sezioni_144
  test "without solo_144 does not include sezioni_144" do
    query = Stats::AdozioniQuery.new(
      filters: {},
      group_by: ["editore"],
      limit: 3
    )
    result = query.call

    refute result[:totals].key?(:sezioni_144)
    result[:results].each do |r|
      refute r.key?(:sezioni_144)
    end
  end

  # 14. solo_144 filters only 144-eligible adozioni and weights correctly
  test "solo_144 filters only 144-eligible and peso 0.5 for AMBITO" do
    conn = ActiveRecord::Base.connection
    conn.execute <<~SQL
      INSERT INTO import_adozioni ("CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "DISCIPLINA", "CODICEISBN", "AUTORI", "TITOLO", "EDITORE", "PREZZO", "DAACQUIST", "NUOVAADOZ", "CONSIGLIATO", "COMBINAZIONE", "TIPOGRADOSCUOLA", created_at, updated_at)
      VALUES
        ('TOEE12345A', '4', 'A', 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)', '9788891901096', 'BIANCHI', 'SCIENZE 4', 'PEARSON', '18,00', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW()),
        ('TOEE12345A', '4', 'A', 'SUSSIDIARIO DEI LINGUAGGI', '9788891901095', 'BIANCHI', 'LING 4', 'PEARSON', '20,00', 'Si', 'Si', 'No', 'TP', 'EE', NOW(), NOW())
    SQL

    query = Stats::AdozioniQuery.new(
      filters: { editore: "PEARSON" },
      group_by: ["editore"],
      solo_144: true,
      order_by: :sezioni_144,
      limit: 1
    )
    result = query.call
    top = result[:results].first

    assert_equal "PEARSON", top[:editore]
    # AMBITO SCIENTIFICO peso 0.5 + SUSSIDIARIO DEI LINGUAGGI peso 1.0 = 1.5
    assert_in_delta 1.5, top[:sezioni_144], 0.1
  end
end
