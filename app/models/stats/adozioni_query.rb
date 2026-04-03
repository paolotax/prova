module Stats
  class AdozioniQuery
    DIMENSIONS = {
      "editore"    => 'ia."EDITORE"',
      "disciplina" => 'ia."DISCIPLINA"',
      "classe"     => 'ia."ANNOCORSO"',
      "provincia"  => 'isc."PROVINCIA"',
      "titolo"     => 'ia."TITOLO"',
      "scuola"     => 'isc."CODICESCUOLA"'
    }.freeze

    EXTRA_COLUMNS = {
      "titolo" => ['ia."CODICEISBN" as isbn', 'ia."AUTORI" as autori', 'ia."PREZZO" as prezzo'],
      "scuola" => ['isc."DENOMINAZIONESCUOLA" as denominazione', 'isc."PROVINCIA" as provincia']
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
      "codice_scuola" => 'isc."CODICESCUOLA" = ?'
    }.freeze

    ORDER_COLUMNS = %w[classi_count scuole_count adozioni_count copie_stimate importo percentuale].freeze

    def initialize(filters:, group_by:, coefficiente: 18, order_by: :classi_count, limit: 50)
      @filters = filters.to_h.stringify_keys.select { |_, v| v.present? }
      @group_by = Array(group_by).map(&:to_s).select { |d| DIMENSIONS.key?(d) }
      @coefficiente = coefficiente
      @order_by = ORDER_COLUMNS.include?(order_by.to_s) ? order_by.to_s : "classi_count"
      @limit = [limit, 500].min
    end

    def call
      {
        filters_applied: @filters,
        group_by: @group_by,
        coefficiente: @coefficiente,
        totals: totals,
        results: results
      }
    end

    private

    def base_from
      <<~SQL
        FROM import_adozioni ia
        INNER JOIN import_scuole isc ON isc."CODICESCUOLA" = ia."CODICESCUOLA"
        INNER JOIN tipi_scuole ts ON ts.tipo = isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
      SQL
    end

    def base_where
      conditions = ['ts.grado = ?', 'ia."DAACQUIST" = ?']
      binds = ["E", "Si"]
      @filters.each do |key, value|
        next unless FILTERS.key?(key)
        conditions << FILTERS[key]
        binds << (%w[titolo editore disciplina scuola].include?(key) ? "%#{value}%" : value)
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
      "#{classi_count_expr} as classi_count, COUNT(DISTINCT ia.\"CODICESCUOLA\") as scuole_count, COUNT(*) as adozioni_count"
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

      {
        classi_count: classi,
        scuole_count: row["scuole_count"].to_i,
        adozioni_count: adozioni,
        copie_stimate: classi * @coefficiente,
        importo_cents: (prezzo_avg * classi * @coefficiente * 100).round
      }
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
        entry
      end
    end

    def column_alias(dimension)
      # Extract the PostgreSQL column name from the dimension expression
      # e.g., 'ia."EDITORE"' -> "EDITORE", 'isc."PROVINCIA"' -> "PROVINCIA"
      DIMENSIONS[dimension].match(/"([^"]+)"/)&.captures&.first
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
