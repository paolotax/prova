module Stats
  class AdozioniQuery
    DIMENSIONS = {
      "editore"    => 'ia."EDITORE"',
      "disciplina" => 'ia."DISCIPLINA"',
      "classe"     => 'ia."ANNOCORSO"',
      "provincia"  => 'isc."PROVINCIA"',
      "comune"     => 'isc."DESCRIZIONECOMUNE"',
      "titolo"     => 'ia."TITOLO"',
      "scuola"     => 'isc."CODICESCUOLA"',
      "grado"      => 'ts.grado'
    }.freeze

    GRADO_ALIASES = {
      "E" => "E", "ELEMENTARI" => "E", "PRIMARIA" => "E",
      "M" => "M", "MEDIE" => "M", "SECONDARIA_I" => "M", "SECONDARIA I" => "M",
      "N" => "N", "S" => "N", "SUPERIORI" => "N", "SECONDARIA_II" => "N", "SECONDARIA II" => "N"
    }.freeze

    EXTRA_COLUMNS = {
      "titolo" => ['ia."CODICEISBN" as isbn', 'ia."AUTORI" as autori', 'ia."PREZZO" as prezzo'],
      "scuola" => ['isc."DENOMINAZIONESCUOLA" as denominazione', 'isc."PROVINCIA" as provincia'],
      "comune" => ['isc."PROVINCIA" as provincia']
    }.freeze

    FILTERS = {
      "provincia"    => 'isc."PROVINCIA" = ?',
      "regione"      => 'isc."REGIONE" = ?',
      "classe"       => 'ia."ANNOCORSO" = ?',
      "editore"      => 'ia."EDITORE" ILIKE ?',
      "disciplina"   => 'ia."DISCIPLINA" ILIKE ?',
      "titolo"       => 'ia."TITOLO" ILIKE ?',
      "isbn"         => 'ia."CODICEISBN" = ?',
      "combinazione" => 'ia."COMBINAZIONE" = ?',
      "scuola"       => 'isc."DENOMINAZIONESCUOLA" ILIKE ?',
      "codice_scuola" => 'isc."CODICESCUOLA" = ?',
      "comune"       => 'isc."DESCRIZIONECOMUNE" ILIKE ?'
    }.freeze

    ORDER_COLUMNS = %w[classi_count scuole_count adozioni_count copie_stimate importo percentuale sezioni_144].freeze

    SIGLA_TO_PROVINCIA = {
      "AG" => "AGRIGENTO", "AL" => "ALESSANDRIA", "AN" => "ANCONA", "AO" => "AOSTA",
      "AR" => "AREZZO", "AP" => "ASCOLI PICENO", "AT" => "ASTI", "AV" => "AVELLINO",
      "BA" => "BARI", "BT" => "BARLETTA-ANDRIA-TRANI", "BL" => "BELLUNO", "BN" => "BENEVENTO",
      "BG" => "BERGAMO", "BI" => "BIELLA", "BO" => "BOLOGNA", "BZ" => "BOLZANO",
      "BS" => "BRESCIA", "BR" => "BRINDISI", "CA" => "CAGLIARI", "CL" => "CALTANISSETTA",
      "CB" => "CAMPOBASSO", "CE" => "CASERTA", "CT" => "CATANIA", "CZ" => "CATANZARO",
      "CH" => "CHIETI", "CO" => "COMO", "CS" => "COSENZA", "CR" => "CREMONA",
      "KR" => "CROTONE", "CN" => "CUNEO", "EN" => "ENNA", "FM" => "FERMO",
      "FE" => "FERRARA", "FI" => "FIRENZE", "FG" => "FOGGIA", "FC" => "FORLI'-CESENA",
      "FR" => "FROSINONE", "GE" => "GENOVA", "GO" => "GORIZIA", "GR" => "GROSSETO",
      "IM" => "IMPERIA", "IS" => "ISERNIA", "SP" => "LA SPEZIA", "AQ" => "L'AQUILA",
      "LT" => "LATINA", "LE" => "LECCE", "LC" => "LECCO", "LI" => "LIVORNO",
      "LO" => "LODI", "LU" => "LUCCA", "MC" => "MACERATA", "MN" => "MANTOVA",
      "MS" => "MASSA-CARRARA", "MT" => "MATERA", "ME" => "MESSINA", "MI" => "MILANO",
      "MO" => "MODENA", "MB" => "MONZA E DELLA BRIANZA", "NA" => "NAPOLI", "NO" => "NOVARA",
      "NU" => "NUORO", "OR" => "ORISTANO", "PD" => "PADOVA", "PA" => "PALERMO",
      "PR" => "PARMA", "PV" => "PAVIA", "PG" => "PERUGIA", "PU" => "PESARO E URBINO",
      "PE" => "PESCARA", "PC" => "PIACENZA", "PI" => "PISA", "PT" => "PISTOIA",
      "PN" => "PORDENONE", "PZ" => "POTENZA", "PO" => "PRATO", "RG" => "RAGUSA",
      "RA" => "RAVENNA", "RC" => "REGGIO CALABRIA", "RE" => "REGGIO EMILIA",
      "RI" => "RIETI", "RN" => "RIMINI", "RM" => "ROMA", "RO" => "ROVIGO",
      "SA" => "SALERNO", "SS" => "SASSARI", "SV" => "SAVONA", "SI" => "SIENA",
      "SR" => "SIRACUSA", "SO" => "SONDRIO", "SU" => "SUD SARDEGNA", "TA" => "TARANTO",
      "TE" => "TERAMO", "TR" => "TERNI", "TO" => "TORINO", "TP" => "TRAPANI",
      "TN" => "TRENTO", "TV" => "TREVISO", "TS" => "TRIESTE", "UD" => "UDINE",
      "VA" => "VARESE", "VE" => "VENEZIA", "VB" => "VERBANO-CUSIO-OSSOLA",
      "VC" => "VERCELLI", "VR" => "VERONA", "VV" => "VIBO VALENTIA", "VI" => "VICENZA",
      "VT" => "VITERBO"
    }.freeze

    def initialize(filters:, group_by:, coefficiente: 18, order_by: :classi_count, limit: 50, solo_144: false, grado: "E")
      @filters = normalize_filters(filters)
      @group_by = Array(group_by).map(&:to_s).select { |d| DIMENSIONS.key?(d) }
      @coefficiente = coefficiente
      @order_by = ORDER_COLUMNS.include?(order_by.to_s) ? order_by.to_s : "classi_count"
      @limit = [limit, 500].min
      @grado = self.class.expand_gradi(grado)
      @solo_144 = solo_144 && @grado == ["E"]
    end

    def self.expand_provincia(value)
      upper = value.to_s.strip.upcase
      SIGLA_TO_PROVINCIA[upper] || upper
    end

    def self.expand_gradi(value)
      list = Array(value).flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:blank?)
      list = ["E"] if list.empty?
      list.map { |g| GRADO_ALIASES[g.upcase] || g.upcase }.uniq
    end

    def call
      {
        filters_applied: @filters,
        grado: @grado,
        group_by: @group_by,
        coefficiente: @coefficiente,
        solo_144: @solo_144 || nil,
        totals: totals,
        results: results
      }.compact
    end

    private

    def normalize_filters(filters)
      h = filters.to_h.stringify_keys.select { |_, v| v.present? }
      h["provincia"] = self.class.expand_provincia(h["provincia"]) if h["provincia"].present?
      h
    end

    def base_from
      <<~SQL
        FROM import_adozioni ia
        INNER JOIN import_scuole isc ON isc."CODICESCUOLA" = ia."CODICESCUOLA"
        INNER JOIN tipi_scuole ts ON ts.tipo = isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
      SQL
    end

    def base_where
      placeholders = Array.new(@grado.size, "?").join(",")
      conditions = ["ts.grado IN (#{placeholders})", 'ia."DAACQUIST" = ?']
      binds = @grado + ["Si"]
      @filters.each do |key, value|
        next unless FILTERS.key?(key)
        conditions << FILTERS[key]
        binds << (%w[titolo editore disciplina scuola comune].include?(key) ? "%#{value}%" : value)
      end
      if @solo_144
        conditions << Stats::Calcolo144.where_clause('ia."DISCIPLINA"', 'ia."ANNOCORSO"')
      end
      [conditions.join(" AND "), binds]
    end

    def group_columns
      @group_by.map { |d| DIMENSIONS[d] }
    end

    def extra_columns
      @group_by.flat_map { |d| EXTRA_COLUMNS.fetch(d, []) }
    end

    def classi_count_expr
      'COUNT(DISTINCT (ia."CODICESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO"))'
    end

    def select_aggregates
      agg = "#{classi_count_expr} as classi_count, COUNT(DISTINCT ia.\"CODICESCUOLA\") as scuole_count, COUNT(*) as adozioni_count"
      agg += ", SUM(#{Stats::Calcolo144.peso_case_sql('ia."DISCIPLINA"')}) as sezioni_144" if @solo_144
      agg
    end

    def prezzo_sum_expr
      'SUM(CAST(NULLIF(REGEXP_REPLACE(REPLACE(ia."PREZZO", \',\', \'.\'), \'[^0-9.]\', \'\', \'g\'), \'\') AS numeric))'
    end

    def totals
      conditions, binds = base_where
      sql = "SELECT #{select_aggregates}, #{prezzo_sum_expr} as prezzo_sum #{base_from} WHERE #{conditions}"
      row = exec_query(sql, binds)

      return { classi_count: 0, scuole_count: 0, adozioni_count: 0, copie_stimate: 0, importo_cents: 0 } if row.nil? || row["classi_count"].to_i == 0

      classi = row["classi_count"].to_i
      adozioni = row["adozioni_count"].to_i
      prezzo_avg = adozioni > 0 ? row["prezzo_sum"].to_f / adozioni : 0

      result = {
        classi_count: classi,
        scuole_count: row["scuole_count"].to_i,
        adozioni_count: adozioni,
        copie_stimate: classi * @coefficiente,
        importo_cents: (prezzo_avg * classi * @coefficiente * 100).round
      }
      result[:sezioni_144] = row["sezioni_144"].to_f.round(1) if @solo_144
      result
    end

    def results
      return [] if @group_by.empty?
      total = totals
      return [] if total[:classi_count] == 0

      conditions, binds = base_where
      gc = group_columns
      ec = extra_columns

      select_parts = (gc + ec + [select_aggregates]).join(", ")
      select_parts += ", #{prezzo_sum_expr} as prezzo_sum"

      group_expr = gc.join(", ")
      # Extra columns that aren't already in group_columns need to be in GROUP BY too
      ec_raw = ec.map { |col| col.split(" as ").first.strip }
      all_group = (gc + ec_raw).uniq.join(", ")

      order_col = @order_by == "percentuale" ? "classi_count" : @order_by
      sql = "SELECT #{select_parts} #{base_from} WHERE #{conditions} GROUP BY #{all_group} ORDER BY #{order_col} DESC LIMIT #{@limit}"

      rows = exec_query_all(sql, binds)
      total_classi = total[:classi_count]

      rows.map do |row|
        entry = {}
        @group_by.each { |d| entry[d.to_sym] = row[column_alias(d)] }

        # Extra columns
        @group_by.each do |d|
          EXTRA_COLUMNS.fetch(d, []).each do |col|
            a = col.split(" as ").last.strip
            entry[a.to_sym] = row[a]
          end
        end

        classi = row["classi_count"].to_i
        adozioni = row["adozioni_count"].to_i
        prezzo_avg = adozioni > 0 ? row["prezzo_sum"].to_f / adozioni : 0

        entry[:classi_count] = classi
        entry[:scuole_count] = row["scuole_count"].to_i
        entry[:adozioni_count] = adozioni
        entry[:copie_stimate] = classi * @coefficiente
        entry[:importo_cents] = (prezzo_avg * classi * @coefficiente * 100).round
        entry[:percentuale] = (classi.to_f / total_classi * 100).round(2)
        entry[:sezioni_144] = row["sezioni_144"].to_f.round(1) if @solo_144
        entry
      end
    end

    def column_alias(dimension)
      # Extract the PostgreSQL column name from the dimension expression
      # e.g., 'ia."EDITORE"' -> "EDITORE", 'ts.grado' -> "grado"
      expr = DIMENSIONS[dimension]
      expr.match(/"([^"]+)"/)&.captures&.first || expr.split(".").last
    end

    def exec_query(sql, binds)
      sanitized = ActiveRecord::Base.sanitize_sql_array([sql, *binds])
      ActiveRecord::Base.connection.select_one(sanitized)
    end

    def exec_query_all(sql, binds)
      sanitized = ActiveRecord::Base.sanitize_sql_array([sql, *binds])
      ActiveRecord::Base.connection.select_all(sanitized)
    end
  end
end
