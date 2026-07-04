class AdozioniAnalytics
  attr_reader :account, :scuola_ids

  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  # Adoptions (da_acquistare), user's schools only,
  # aggregated by (grado, disciplina, anno_corso, titolo/isbn/editore).
  # solo_mie: true → only mia=true (mie adozioni). false → all in scope (mie + concorrenza).
  def adozioni(filtri: {}, solo_mie: true, anno_scolastico: nil)
    scope = account.adozioni
    scope = scope.mie if solo_mie
    scope = scope.where(da_acquistare: true)
                 .joins(classe: :scuola)
                 .where(classi: { scuola_id: scuola_ids })
    scope = scope_anno(scope, anno_scolastico)

    scope = apply_filtri(scope, filtri)

    scope.group("scuole.grado", "adozioni.anno_corso",
                :disciplina, :titolo, :editore, :codice_isbn)
      .select(
        "scuole.grado AS grado",
        "adozioni.anno_corso AS anno_corso",
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * #{Stats::Calcolo144.peso_mercato_case_sql('adozioni.disciplina')} AS sezioni_pesate",
        "COUNT(DISTINCT adozioni.classe_id) * 17 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order("scuole.grado", :disciplina, "adozioni.anno_corso",
             Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
  end

  # national_* leggono dalle materialized view rollup, filtrate sull'anno
  # scolastico richiesto e pesate (fascicoli AMBITO = 0.5 sezioni).
  # Hash: { [grado, disciplina, anno_corso, codice_isbn] => sezioni_pesate }
  def national_book_shares(rows, anno_scolastico:)
    return {} if anno_scolastico.blank?

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
      WHERE r.anno_scolastico = #{ActiveRecord::Base.connection.quote(anno_scolastico)}
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, isbn, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno, isbn]] += sez.to_i * Stats::Calcolo144.peso_mercato_for(disc)
    end
    result
  end

  # Hash: { [grado, disciplina, anno_corso] => totale_sezioni_pesate }
  def national_market_totals(rows, anno_scolastico:)
    return {} if anno_scolastico.blank?

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
      WHERE r.anno_scolastico = #{ActiveRecord::Base.connection.quote(anno_scolastico)}
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno]] += sez.to_i * Stats::Calcolo144.peso_mercato_for(disc)
    end
    result
  end

  # Usa la matview mercato_scuola_mercati: aggrega le sezioni delle sole scuole indicate.
  # Hash: { [grado, disciplina, anno_corso] => totale_sezioni_pesate_in_zona }
  def zone_market_totals(rows, codici_ministeriali:, anno_scolastico:)
    return {} if codici_ministeriali.blank? || anno_scolastico.blank?

    tuples = rows.flat_map { |r|
      (GRADO_TO_TG[r.grado] || []).map { |tg| [tg, r.disciplina, r.anno_corso.to_s] }
    }.uniq.reject { |t| t.any?(&:blank?) }
    return {} if tuples.empty?

    quoted_codici = codici_ministeriali.map { |c| ActiveRecord::Base.connection.quote(c) }.join(", ")

    sql = <<~SQL
      WITH m (tg, disciplina, anno_corso) AS (VALUES #{tuples_sql(tuples)})
      SELECT r.tipo_grado_scuola, r.disciplina, r.anno_corso, SUM(r.sezioni) AS sezioni
      FROM mercato_scuola_mercati r
      JOIN m ON m.tg         = r.tipo_grado_scuola
            AND m.disciplina = r.disciplina
            AND m.anno_corso = r.anno_corso
      WHERE r.codice_scuola IN (#{quoted_codici})
        AND r.anno_scolastico = #{ActiveRecord::Base.connection.quote(anno_scolastico)}
      GROUP BY 1, 2, 3
    SQL

    result = Hash.new(0)
    ActiveRecord::Base.connection.exec_query(sql).rows.each do |row|
      tg, disc, anno, sez = row
      grado = TG_TO_GRADO[tg] or next
      result[[grado, disc, anno]] += sez.to_i * Stats::Calcolo144.peso_mercato_for(disc)
    end
    result
  end

  def self.refresh_rollup!
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mercato_nazionale_libri")
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mercato_nazionale_mercati")
    ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mercato_scuola_mercati")
  end

  # Available filter options scoped to adozioni da_acquistare in user's schools
  # 1 bulk query for all options, then 1 query per active filter (except itself)
  def filter_options(filtri: {}, solo_mie: true, anno_scolastico: nil)
    base = account.adozioni
    base = base.mie if solo_mie
    base = base.where(da_acquistare: true)
               .joins(classe: :scuola)
               .where(classi: { scuola_id: scuola_ids })
    base = scope_anno(base, anno_scolastico)

    # 1 query: all distinct values from fully-filtered scope
    filtered = apply_filtri(base, filtri)
    result = bulk_pluck_options(filtered)

    # For each active filter, override its options from except-scope
    filtri.each_key do |key|
      next unless OPTION_SQL.key?(key)
      except_scope = apply_filtri(base, filtri.except(key))
      override_filter_option(result, key, except_scope)
    end

    # Anni scolastici disponibili: indipendenti dall'anno selezionato (per poter switchare)
    result[:anni_scolastici] = anni_scolastici_disponibili(solo_mie)

    result
  end

  # Annata più recente presente tra le adozioni in scope: è il default quando
  # l'utente non seleziona un anno. Con classi/adozioni di due campagne in
  # tabella, "corrente" deve essere UN anno preciso, mai un mix.
  def anno_corrente
    return @anno_corrente if defined?(@anno_corrente)

    @anno_corrente = account.adozioni
                            .where(da_acquistare: true)
                            .joins(:classe).where(classi: { scuola_id: scuola_ids })
                            .maximum(:anno_scolastico)
  end

  private

  # Snapshot dell'anno richiesto, oppure dell'anno corrente (il più recente).
  def scope_anno(scope, anno_scolastico)
    scope.where(adozioni: { anno_scolastico: anno_scolastico.presence || anno_corrente })
  end

  def anni_scolastici_disponibili(solo_mie)
    s = account.adozioni
    s = s.mie if solo_mie
    s.where(da_acquistare: true)
     .joins(:classe).where(classi: { scuola_id: scuola_ids })
     .distinct.pluck(:anno_scolastico).compact.reject(&:blank?).sort.reverse
  end

  # Mappa grado (scuole.grado) → TIPOGRADOSCUOLA in import_adozioni:
  # EE=primaria, MM=medie, NT/NO=superiori (due varianti per lo stesso grado "N")
  GRADO_TO_TG = {
    "E" => %w[EE],
    "M" => %w[MM],
    "N" => %w[NT NO]
  }.freeze

  TG_TO_GRADO = { "EE" => "E", "MM" => "M", "NT" => "N", "NO" => "N" }.freeze

  def tuples_sql(tuples)
    tuples.map { |t| "(#{t.map { |v| ActiveRecord::Base.connection.quote(v) }.join(", ")})" }.join(", ")
  end

  OPTION_SQL = {
    disciplina: "array_agg(DISTINCT adozioni.disciplina)",
    editore: "array_agg(DISTINCT adozioni.editore)",
    gruppo: "array_agg(DISTINCT adozioni.editore)",
    regione: "array_agg(DISTINCT scuole.regione)",
    provincia: "array_agg(DISTINCT scuole.provincia)",
    grado: "array_agg(DISTINCT scuole.grado)",
    tipo_scuola: "array_agg(DISTINCT scuole.tipo_scuola)",
    area: "array_agg(DISTINCT scuole.area)",
    anno_corso: "array_agg(DISTINCT adozioni.anno_corso)"
  }.freeze

  OPTION_RESULT_KEY = {
    disciplina: :discipline, editore: :editori, gruppo: :gruppi,
    regione: :regioni, provincia: :province, grado: :gradi,
    tipo_scuola: :tipi_scuola, area: :aree, anno_corso: :anni_corso
  }.freeze

  def bulk_pluck_options(scope)
    row = scope.pick(
      Arel.sql(OPTION_SQL[:disciplina]),
      Arel.sql(OPTION_SQL[:editore]),
      Arel.sql(OPTION_SQL[:regione]),
      Arel.sql(OPTION_SQL[:provincia]),
      Arel.sql(OPTION_SQL[:grado]),
      Arel.sql(OPTION_SQL[:tipo_scuola]),
      Arel.sql(OPTION_SQL[:area]),
      Arel.sql(OPTION_SQL[:anno_corso])
    )
    row ||= Array.new(8)

    editori = (row[1] || []).compact.sort
    {
      discipline: (row[0] || []).compact.sort,
      editori: editori,
      gruppi: Editore.where(editore: editori).pluck(:gruppo).compact.uniq.sort,
      regioni: (row[2] || []).compact.sort,
      province: (row[3] || []).compact.sort,
      gradi: (row[4] || []).compact.sort,
      tipi_scuola: (row[5] || []).compact.sort,
      aree: (row[6] || []).compact.reject { |a| a.start_with?("__") }.sort,
      anni_corso: (row[7] || []).compact.sort
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
    scope = scope.where(adozioni: { anno_corso: filtri[:anno_corso] }) if filtri[:anno_corso].present?
    scope = scope.where(editore: filtri[:editore]) if filtri[:editore].present?
    if filtri[:gruppo].present?
      editore_names = Editore.where(gruppo: filtri[:gruppo]).pluck(:editore)
      scope = scope.where(editore: editore_names)
    end
    scope = scope.joins(classe: :scuola).where(scuole: { regione: filtri[:regione] }) if filtri[:regione].present?
    scope = scope.joins(classe: :scuola).where(scuole: { provincia: filtri[:provincia] }) if filtri[:provincia].present?
    scope = scope.joins(classe: :scuola).where(scuole: { grado: filtri[:grado] }) if filtri[:grado].present?
    scope = scope.joins(classe: :scuola).where(scuole: { tipo_scuola: filtri[:tipo_scuola] }) if filtri[:tipo_scuola].present?
    scope = scope.joins(classe: :scuola).where(scuole: { area: filtri[:area] }) if filtri[:area].present?
    scope
  end

end
