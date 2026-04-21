class AdozioniAnalytics
  attr_reader :account, :scuola_ids

  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  # Tab "Le mie" — my adoptions (mie, da_acquistare), user's schools only
  def mie_adozioni(filtri: {})
    scope = account.adozioni.mie
      .where(da_acquistare: true)
      .joins(classe: :scuola)
      .where(classi: { scuola_id: scuola_ids })

    scope = apply_filtri(scope, filtri)

    scope.group("scuole.grado", "classi.anno_corso",
                :disciplina, :titolo, :editore, :codice_isbn)
      .select(
        "scuole.grado AS grado",
        "classi.anno_corso AS anno_corso",
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order("scuole.grado", :disciplina, "classi.anno_corso",
             Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
  end

  # Tab "Agenzia" — all account's mie adozioni (includes disdette)
  def agenzia(filtri: {})
    scope = account.adozioni.mie

    scope = apply_filtri(scope, filtri)

    scope.group(:disciplina, :titolo, :editore, :codice_isbn)
      .select(
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order(:disciplina, Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
  end

  # Tab "Confronto editori" — from import_adozioni, account's schools
  def confronto_editori(filtri: {})
    codici = account.scuole.where(id: scuola_ids)
      .where.not(codice_ministeriale: [nil, ""])
      .pluck(:codice_ministeriale)

    return [] if codici.empty?

    scope = ImportAdozione.where(CODICESCUOLA: codici, DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") DESC'))
      .select(
        :EDITORE, :DISCIPLINA, :ANNOCORSO,
        'COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") AS sezioni_count'
      )
  end

  # Tab "Dati provincia" — from import_adozioni, entire province
  def dati_provincia(provincia:, filtri: {})
    scope = ImportAdozione
      .joins("JOIN import_scuole ON import_scuole.\"CODICESCUOLA\" = import_adozioni.\"CODICESCUOLA\"")
      .where(import_scuole: { PROVINCIA: provincia })
      .where(DAACQUIST: "Si")

    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT import_adozioni."CODICESCUOLA" || \'_\' || import_adozioni."ANNOCORSO" || \'_\' || import_adozioni."SEZIONEANNO") DESC'))
      .select(
        'import_adozioni."EDITORE"', 'import_adozioni."DISCIPLINA"', 'import_adozioni."ANNOCORSO"',
        'COUNT(DISTINCT import_adozioni."CODICESCUOLA" || \'_\' || import_adozioni."ANNOCORSO" || \'_\' || import_adozioni."SEZIONEANNO") AS sezioni_count'
      )
  end

  # Tab "Dati nazionali" — from import_adozioni, all Italy
  def dati_nazionali(filtri: {})
    scope = ImportAdozione.where(DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") DESC'))
      .select(
        :EDITORE, :DISCIPLINA, :ANNOCORSO,
        'COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") AS sezioni_count'
      )
  end

  # national_* leggono dalle materialized view rollup.
  # Hash: { [grado, disciplina, anno_corso, codice_isbn] => sezioni }
  def national_book_shares(rows)
    tuples = rows.flat_map { |r|
      (GRADO_TO_TG[r.grado] || []).map { |tg| [tg, r.disciplina, r.anno_corso.to_s, r.codice_isbn] }
    }.uniq.reject { |t| t.any?(&:blank?) }
    return {} if tuples.empty?

    sql = <<~SQL
      WITH m (tg, disciplina, anno_corso, codice_isbn) AS (VALUES #{tuples_sql(tuples)})
      SELECT r.tipo_grado_scuola, r.disciplina, r.anno_corso, r.codice_isbn, r.sezioni
      FROM mercato_nazionale_libri r
      JOIN m ON m.tg          = r.tipo_grado_scuola
            AND m.disciplina  = r.disciplina
            AND m.anno_corso  = r.anno_corso
            AND m.codice_isbn = r.codice_isbn
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, isbn, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno, isbn]] += sez.to_i
    end
    result
  end

  # Hash: { [grado, disciplina, anno_corso] => totale_sezioni }
  def national_market_totals(rows)
    tuples = rows.flat_map { |r|
      (GRADO_TO_TG[r.grado] || []).map { |tg| [tg, r.disciplina, r.anno_corso.to_s] }
    }.uniq.reject { |t| t.any?(&:blank?) }
    return {} if tuples.empty?

    sql = <<~SQL
      WITH m (tg, disciplina, anno_corso) AS (VALUES #{tuples_sql(tuples)})
      SELECT r.tipo_grado_scuola, r.disciplina, r.anno_corso, r.sezioni
      FROM mercato_nazionale_mercati r
      JOIN m ON m.tg         = r.tipo_grado_scuola
            AND m.disciplina = r.disciplina
            AND m.anno_corso = r.anno_corso
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno]] += sez.to_i
    end
    result
  end

  def zone_book_shares(rows, codici_ministeriali:)
    book_shares(rows, codici_ministeriali: codici_ministeriali)
  end

  def zone_market_totals(rows, codici_ministeriali:)
    market_totals(rows, codici_ministeriali: codici_ministeriali)
  end

  def self.refresh_rollup!
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mercato_nazionale_libri")
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mercato_nazionale_mercati")
  end

  # Available filter options scoped to mie adozioni da_acquistare
  # 1 bulk query for all options, then 1 query per active filter (except itself)
  def mie_filter_options(filtri: {})
    base = account.adozioni.mie.where(da_acquistare: true)
      .joins(classe: :scuola)
      .where(classi: { scuola_id: scuola_ids })

    # 1 query: all distinct values from fully-filtered scope
    filtered = apply_filtri(base, filtri)
    result = bulk_pluck_options(filtered)

    # For each active filter, override its options from except-scope
    filtri.each_key do |key|
      next unless OPTION_SQL.key?(key)
      except_scope = apply_filtri(base, filtri.except(key))
      override_filter_option(result, key, except_scope)
    end

    result
  end

  # Available filter options for all adozioni (other tabs)
  def discipline_options
    account.adozioni.distinct.pluck(:disciplina).compact.sort
  end

  def editori_options
    account.adozioni.distinct.pluck(:editore).compact.sort
  end

  private

  # Mappa grado (scuole.grado) → TIPOGRADOSCUOLA in import_adozioni:
  # EE=primaria, MM=medie, NT/NO=superiori (due varianti per lo stesso grado "N")
  GRADO_TO_TG = {
    "E" => %w[EE],
    "M" => %w[MM],
    "N" => %w[NT NO]
  }.freeze

  TG_TO_GRADO = { "EE" => "E", "MM" => "M", "NT" => "N", "NO" => "N" }.freeze

  def book_shares(rows, codici_ministeriali: nil)
    tuples = rows.flat_map { |r|
      (GRADO_TO_TG[r.grado] || []).map { |tg| [tg, r.disciplina, r.anno_corso.to_s, r.codice_isbn] }
    }.uniq.reject { |t| t.any?(&:blank?) }
    return {} if tuples.empty?

    # VALUES CTE: consente hash join efficiente invece di nested-loop su tuple IN
    values_rows = tuples.map { |t| "(#{t.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")})" }.join(", ")
    discipline  = tuples.map { |t| t[1] }.uniq
    disc_list   = discipline.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")

    sql = <<~SQL
      WITH m (tg, disciplina, anno_corso, codice_isbn) AS (VALUES #{values_rows})
      SELECT im_ad."TIPOGRADOSCUOLA" AS tg,
             im_ad."DISCIPLINA"      AS disciplina,
             im_ad."ANNOCORSO"       AS anno_corso,
             im_ad."CODICEISBN"      AS codice_isbn,
             COUNT(DISTINCT im_ad."CODICESCUOLA" || '_' || im_ad."ANNOCORSO" || '_' || im_ad."SEZIONEANNO") AS sezioni
      FROM import_adozioni im_ad
      JOIN m ON m.tg         = im_ad."TIPOGRADOSCUOLA"
            AND m.disciplina = im_ad."DISCIPLINA"
            AND m.anno_corso = im_ad."ANNOCORSO"
            AND m.codice_isbn = im_ad."CODICEISBN"
      WHERE im_ad."DAACQUIST" = 'Si'
        AND im_ad."DISCIPLINA" IN (#{disc_list})
        #{scuola_filter_sql(codici_ministeriali)}
      GROUP BY 1, 2, 3, 4
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, isbn, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno, isbn]] += sez.to_i
    end
    result
  end

  def market_totals(rows, codici_ministeriali: nil)
    tuples = rows.flat_map { |r|
      (GRADO_TO_TG[r.grado] || []).map { |tg| [tg, r.disciplina, r.anno_corso.to_s] }
    }.uniq.reject { |t| t.any?(&:blank?) }
    return {} if tuples.empty?

    values_rows = tuples.map { |t| "(#{t.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")})" }.join(", ")
    discipline  = tuples.map { |t| t[1] }.uniq
    disc_list   = discipline.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")

    sql = <<~SQL
      WITH m (tg, disciplina, anno_corso) AS (VALUES #{values_rows})
      SELECT im_ad."TIPOGRADOSCUOLA" AS tg,
             im_ad."DISCIPLINA"      AS disciplina,
             im_ad."ANNOCORSO"       AS anno_corso,
             COUNT(DISTINCT im_ad."CODICESCUOLA" || '_' || im_ad."ANNOCORSO" || '_' || im_ad."SEZIONEANNO") AS sezioni
      FROM import_adozioni im_ad
      JOIN m ON m.tg         = im_ad."TIPOGRADOSCUOLA"
            AND m.disciplina = im_ad."DISCIPLINA"
            AND m.anno_corso = im_ad."ANNOCORSO"
      WHERE im_ad."DAACQUIST" = 'Si'
        AND im_ad."DISCIPLINA" IN (#{disc_list})
        #{scuola_filter_sql(codici_ministeriali)}
      GROUP BY 1, 2, 3
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno]] += sez.to_i
    end
    result
  end

  def tuples_sql(tuples)
    tuples.map { |t| "(#{t.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")})" }.join(", ")
  end

  def scuola_filter_sql(codici_ministeriali)
    return "" if codici_ministeriali.blank?

    list = codici_ministeriali.map { |c| ActiveRecord::Base.connection.quote(c) }.join(", ")
    "AND im_ad.\"CODICESCUOLA\" IN (#{list})"
  end

  OPTION_SQL = {
    disciplina: "array_agg(DISTINCT adozioni.disciplina)",
    editore: "array_agg(DISTINCT adozioni.editore)",
    gruppo: "array_agg(DISTINCT adozioni.editore)",
    provincia: "array_agg(DISTINCT scuole.provincia)",
    grado: "array_agg(DISTINCT scuole.grado)",
    tipo_scuola: "array_agg(DISTINCT scuole.tipo_scuola)",
    area: "array_agg(DISTINCT scuole.area)",
    anno_corso: "array_agg(DISTINCT classi.anno_corso::text)"
  }.freeze

  OPTION_RESULT_KEY = {
    disciplina: :discipline, editore: :editori, gruppo: :gruppi,
    provincia: :province, grado: :gradi, tipo_scuola: :tipi_scuola,
    area: :aree, anno_corso: :anni_corso
  }.freeze

  def bulk_pluck_options(scope)
    row = scope.pick(
      Arel.sql(OPTION_SQL[:disciplina]),
      Arel.sql(OPTION_SQL[:editore]),
      Arel.sql(OPTION_SQL[:provincia]),
      Arel.sql(OPTION_SQL[:grado]),
      Arel.sql(OPTION_SQL[:tipo_scuola]),
      Arel.sql(OPTION_SQL[:area]),
      Arel.sql(OPTION_SQL[:anno_corso])
    )
    row ||= Array.new(7)

    editori = (row[1] || []).compact.sort
    {
      discipline: (row[0] || []).compact.sort,
      editori: editori,
      gruppi: Editore.where(editore: editori).pluck(:gruppo).compact.uniq.sort,
      province: (row[2] || []).compact.sort,
      gradi: (row[3] || []).compact.sort,
      tipi_scuola: (row[4] || []).compact.sort,
      aree: (row[5] || []).compact.reject { |a| a.start_with?("__") }.sort,
      anni_corso: (row[6] || []).compact.sort
    }
  end

  def override_filter_option(result, key, scope)
    values = (scope.pick(Arel.sql(OPTION_SQL[key])) || []).compact

    case key
    when :gruppo
      result[:gruppi] = Editore.where(editore: values).pluck(:gruppo).compact.uniq.sort
    when :area
      result[:aree] = values.reject { |a| a.start_with?("__") }.sort
    else
      result[OPTION_RESULT_KEY[key]] = values.sort
    end
  end

  def apply_filtri(scope, filtri)
    case filtri[:adozioni_tipo]
    when "144"
      scope = scope.adozioni_144
    when "235"
      scope = scope.scorrimenti_235
    end
    scope = scope.where(disciplina: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.joins(:classe).where(classi: { anno_corso: filtri[:anno_corso] }) if filtri[:anno_corso].present?
    scope = scope.where(editore: filtri[:editore]) if filtri[:editore].present?
    if filtri[:gruppo].present?
      editore_names = Editore.where(gruppo: filtri[:gruppo]).pluck(:editore)
      scope = scope.where(editore: editore_names)
    end
    scope = scope.joins(classe: :scuola).where(scuole: { provincia: filtri[:provincia] }) if filtri[:provincia].present?
    scope = scope.joins(classe: :scuola).where(scuole: { grado: filtri[:grado] }) if filtri[:grado].present?
    scope = scope.joins(classe: :scuola).where(scuole: { tipo_scuola: filtri[:tipo_scuola] }) if filtri[:tipo_scuola].present?
    scope = scope.joins(classe: :scuola).where(scuole: { area: filtri[:area] }) if filtri[:area].present?
    scope
  end

  def apply_filtri_import(scope, filtri)
    case filtri[:adozioni_tipo]
    when "144"
      scope = scope.adozioni_144
    when "235"
      scope = scope.scorrimenti_235
    end
    scope = scope.where(DISCIPLINA: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.where(ANNOCORSO: filtri[:anno_corso]) if filtri[:anno_corso].present?
    scope = scope.where(EDITORE: filtri[:editore]) if filtri[:editore].present?
    scope
  end
end
