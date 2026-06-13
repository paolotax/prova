module Stats
  class NewAdozioniQuery
    FILIERA_CASE_SQL = <<~SQL.squish.freeze
      CASE
        WHEN ts.tipo ILIKE 'LICEO%' THEN 'liceo'
        WHEN ts.tipo ILIKE 'IST PROF%' THEN 'professionale'
        WHEN ts.tipo ILIKE 'ISTITUTO TECNICO%' OR ts.tipo ILIKE 'IST TEC%' OR ts.tipo ILIKE 'IST TECNICO%' THEN 'tecnico'
        ELSE 'altro'
      END
    SQL

    DIMENSIONS = {
      "editore"     => 'na.editore',
      "disciplina"  => 'na.disciplina',
      "classe"      => 'na.annocorso',
      "regione"     => 'ns.regione',
      "area"        => 'ns.area_geografica',
      "provincia"   => 'ns.provincia',
      "comune"      => 'ns.comune',
      "titolo"      => 'na.titolo',
      "isbn"        => 'na.codiceisbn',
      "scuola"      => 'na.codicescuola',
      "grado"       => 'ts.grado',
      "tipo_scuola" => 'ts.tipo',
      "filiera"     => FILIERA_CASE_SQL,
      "nuova_adozione" => 'na.nuovaadoz'
    }.freeze

    FILIERA_VALUES = %w[liceo tecnico professionale altro].freeze

    FILIERA_WHERE = {
      "liceo"         => "ts.tipo ILIKE 'LICEO%'",
      "professionale" => "ts.tipo ILIKE 'IST PROF%'",
      "tecnico"       => "(ts.tipo ILIKE 'ISTITUTO TECNICO%' OR ts.tipo ILIKE 'IST TEC%' OR ts.tipo ILIKE 'IST TECNICO%')",
      "altro"         => "NOT (ts.tipo ILIKE 'LICEO%' OR ts.tipo ILIKE 'IST PROF%' OR ts.tipo ILIKE 'ISTITUTO TECNICO%' OR ts.tipo ILIKE 'IST TEC%' OR ts.tipo ILIKE 'IST TECNICO%')"
    }.freeze

    GRADO_ALIASES = {
      "E" => "E", "ELEMENTARI" => "E", "PRIMARIA" => "E",
      "M" => "M", "MEDIE" => "M", "SECONDARIA_I" => "M", "SECONDARIA I" => "M",
      "N" => "N", "S" => "N", "SUPERIORI" => "N", "SECONDARIA_II" => "N", "SECONDARIA II" => "N"
    }.freeze

    EXTRA_COLUMNS = {
      "titolo" => ['na.codiceisbn as isbn', 'na.autori as autori', 'na.prezzo as prezzo'],
      "isbn"   => ['na.titolo as titolo', 'na.autori as autori', 'na.editore as editore', 'na.disciplina as disciplina', 'na.prezzo as prezzo'],
      "scuola" => ['ns.denominazione as denominazione', 'ns.provincia as provincia'],
      "comune" => ['ns.provincia as provincia']
    }.freeze

    FILTERS = {
      "provincia"     => 'ns.provincia = ?',
      "regione"       => 'ns.regione = ?',
      "area"          => 'ns.area_geografica = ?',
      "classe"        => 'na.annocorso = ?',
      "editore"       => 'na.editore ILIKE ?',
      "disciplina"    => 'na.disciplina ILIKE ?',
      "titolo"        => 'na.titolo ILIKE ?',
      "isbn"          => 'na.codiceisbn = ?',
      "combinazione"  => 'na.combinazione = ?',
      "scuola"        => 'ns.denominazione ILIKE ?',
      "codice_scuola" => 'ns.codice_scuola = ?',
      "comune"        => 'ns.comune ILIKE ?',
      "nuova_adozione" => 'na.nuovaadoz = ?'
    }.freeze

    ORDER_COLUMNS = %w[classi_count scuole_count adozioni_count copie_stimate importo percentuale sezioni_144].freeze

    SIGLA_TO_PROVINCIA = AdozioniQuery::SIGLA_TO_PROVINCIA

    DEFAULT_GRADI = %w[E M N].freeze

    def initialize(filters:, group_by:, coefficiente: 17, order_by: :classi_count, limit: 50, offset: 0, solo_144: false, grado: nil, include_sezioni: false, filiera: nil)
      @filters = normalize_filters(filters)
      @group_by = Array(group_by).map(&:to_s).select { |d| DIMENSIONS.key?(d) }
      @coefficiente = coefficiente
      @order_by = ORDER_COLUMNS.include?(order_by.to_s) ? order_by.to_s : "classi_count"
      @limit = limit.to_i.clamp(1, 200)
      @offset = [offset.to_i, 0].max
      @grado = self.class.expand_gradi(grado)
      @solo_144 = solo_144 && @grado == ["E"]
      @include_sezioni = include_sezioni
      @filiera = self.class.expand_filiera(filiera)
    end

    def self.expand_provincia(value)
      upper = value.to_s.strip.upcase
      SIGLA_TO_PROVINCIA[upper] || upper
    end

    # Normalizza il filtro nuova_adozione verso i valori del MIUR ("Si"/"No").
    # Accetta booleani e i sinonimi più comuni; lascia invariato il resto.
    def self.normalize_nuova_adozione(value)
      case value.to_s.strip.downcase
      when "true", "si", "sì", "s", "yes", "y", "1" then "Si"
      when "false", "no", "n", "0"                  then "No"
      else value.to_s.strip
      end
    end

    def self.expand_gradi(value)
      list = Array(value).flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:blank?)
      list = DEFAULT_GRADI.dup if list.empty?
      list.map { |g| GRADO_ALIASES[g.upcase] || g.upcase }.uniq
    end

    def self.expand_filiera(value)
      list = Array(value).flat_map { |v| v.to_s.split(",") }.map { |s| s.strip.downcase }.reject(&:blank?)
      return nil if list.empty?
      list.select { |f| FILIERA_VALUES.include?(f) }.presence
    end

    def call
      rows = results
      {
        filters_applied: @filters,
        grado: @grado,
        filiera: @filiera,
        group_by: @group_by,
        coefficiente: @coefficiente,
        solo_144: @solo_144 || nil,
        pagination: @group_by.empty? ? nil : { offset: @offset, limit: @limit, total_groups: total_groups, returned: rows.size },
        totals: totals,
        results: rows
      }.compact
    end

    private

    def normalize_filters(filters)
      h = filters.to_h.stringify_keys
      # Normalizza nuova_adozione prima del filtro present?: il booleano false è un
      # valore valido ("No") ma false.present? è false e verrebbe scartato.
      h["nuova_adozione"] = self.class.normalize_nuova_adozione(h["nuova_adozione"]) unless h["nuova_adozione"].nil?
      h = h.select { |_, v| v.present? }
      h["provincia"] = self.class.expand_provincia(h["provincia"]) if h["provincia"].present?
      h
    end

    def base_from
      <<~SQL
        FROM new_adozioni na
        INNER JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        INNER JOIN tipi_scuole ts ON ts.tipo = ns.tipo_scuola
      SQL
    end

    def base_where
      placeholders = Array.new(@grado.size, "?").join(",")
      conditions = ["ts.grado IN (#{placeholders})", "na.daacquist = ?"]
      binds = @grado + ["Si"]
      @filters.each do |key, value|
        next unless FILTERS.key?(key)
        conditions << FILTERS[key]
        binds << (%w[titolo editore disciplina scuola comune].include?(key) ? "%#{value}%" : value)
      end
      if @filiera
        conditions << "(#{@filiera.map { |f| FILIERA_WHERE.fetch(f) }.join(' OR ')})"
      end
      if @solo_144
        conditions << Stats::Calcolo144.where_clause('na.disciplina', 'na.annocorso')
      end
      [conditions.join(" AND "), binds]
    end

    def group_columns
      @group_by.map { |d| DIMENSIONS[d] }
    end

    def select_dimensions
      @group_by.map do |d|
        sql = DIMENSIONS[d]
        if sql.match?(/\A\w+\.\w+\z/)
          sql
        else
          "(#{sql}) AS #{column_alias(d)}"
        end
      end
    end

    def extra_columns
      @group_by.flat_map { |d| EXTRA_COLUMNS.fetch(d, []) }
    end

    def classi_count_expr
      'COUNT(DISTINCT (na.codicescuola, na.annocorso, na.sezioneanno))'
    end

    def select_aggregates
      agg = "#{classi_count_expr} as classi_count, COUNT(DISTINCT na.codicescuola) as scuole_count, COUNT(*) as adozioni_count"
      agg += ", SUM(#{Stats::Calcolo144.peso_case_sql('na.disciplina')}) as sezioni_144" if @solo_144
      agg += ", #{sezioni_agg_expr} as sezioni" if @include_sezioni
      agg
    end

    def sezioni_agg_expr
      <<~SQL.squish
        array_agg(DISTINCT
          na.annocorso || na.sezioneanno
          || CASE WHEN NULLIF(na.combinazione, '') IS NOT NULL
                  THEN ' [' || na.combinazione || ']' ELSE '' END
        )
      SQL
    end

    def prezzo_sum_expr
      'SUM(CAST(NULLIF(REGEXP_REPLACE(REPLACE(na.prezzo, \',\', \'.\'), \'[^0-9.]\', \'\', \'g\'), \'\') AS numeric))'
    end

    def totals
      conditions, binds = base_where
      sql = "SELECT #{select_aggregates}, #{prezzo_sum_expr} as prezzo_sum #{base_from} WHERE #{conditions}"
      row = exec_query(sql, binds)

      return { classi_count: 0, scuole_count: 0, adozioni_count: 0, copie_stimate: 0, importo_cents: 0 } if row.nil? || row["classi_count"].to_i == 0

      classi = row["classi_count"].to_i
      adozioni = row["adozioni_count"].to_i
      prezzo_sum = row["prezzo_sum"].to_f

      result = {
        classi_count: classi,
        scuole_count: row["scuole_count"].to_i,
        adozioni_count: adozioni,
        studenti_stimati: classi * @coefficiente,
        copie_stimate: adozioni * @coefficiente,
        importo_cents: (prezzo_sum * @coefficiente * 100).round
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
      sd = select_dimensions
      ec = extra_columns

      select_parts = (sd + ec + [select_aggregates]).join(", ")
      select_parts += ", #{prezzo_sum_expr} as prezzo_sum"

      ec_raw = ec.map { |col| col.split(" as ").first.strip }
      all_group = (gc + ec_raw).uniq.join(", ")

      order_col = @order_by == "percentuale" ? "classi_count" : @order_by
      sql = "SELECT #{select_parts} #{base_from} WHERE #{conditions} GROUP BY #{all_group} ORDER BY #{order_col} DESC LIMIT #{@limit} OFFSET #{@offset}"

      rows = exec_query_all(sql, binds)
      total_classi = total[:classi_count]

      rows.map do |row|
        entry = {}
        @group_by.each { |d| entry[d.to_sym] = row[column_alias(d)] }

        @group_by.each do |d|
          EXTRA_COLUMNS.fetch(d, []).each do |col|
            a = col.split(" as ").last.strip
            entry[a.to_sym] = row[a]
          end
        end

        classi = row["classi_count"].to_i
        adozioni = row["adozioni_count"].to_i
        prezzo_sum = row["prezzo_sum"].to_f

        entry[:classi_count] = classi
        entry[:scuole_count] = row["scuole_count"].to_i
        entry[:adozioni_count] = adozioni
        entry[:studenti_stimati] = classi * @coefficiente
        entry[:copie_stimate] = adozioni * @coefficiente
        entry[:importo_cents] = (prezzo_sum * @coefficiente * 100).round
        entry[:percentuale] = (classi.to_f / total_classi * 100).round(2)
        entry[:sezioni_144] = row["sezioni_144"].to_f.round(1) if @solo_144
        entry[:sezioni] = parse_sezioni(row["sezioni"]) if @include_sezioni
        entry
      end
    end

    def total_groups
      return 0 if @group_by.empty?
      conditions, binds = base_where
      gc = group_columns
      ec_raw = extra_columns.map { |col| col.split(" as ").first.strip }
      all_group = (gc + ec_raw).uniq.join(", ")
      sql = "SELECT COUNT(*) as n FROM (SELECT 1 #{base_from} WHERE #{conditions} GROUP BY #{all_group}) sub"
      exec_query(sql, binds)["n"].to_i
    end

    def parse_sezioni(raw)
      return [] if raw.blank?
      return raw if raw.is_a?(Array)
      raw.to_s.delete("{}").split(",").map { |s| s.strip.delete('"') }.reject(&:blank?).sort
    end

    def column_alias(dimension)
      return "filiera" if dimension == "filiera"
      expr = DIMENSIONS[dimension]
      expr.split(".").last
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
