module Stats
  module Calcolo144
    CLASSI_144 = %w[1 4].freeze
    CLASSI_235 = %w[2 3 5].freeze

    DISCIPLINE_PATTERN = /SUSSIDIARIO|LIBRO DELLA PRIMA/
    FASCICOLO_PATTERN = /AMBITO/

    class << self
      def discipline_144
        @discipline_144 ||= load_from_prezzi_ministeriali
      end

      def discipline_names
        discipline_144.keys
      end

      def peso_for(disciplina)
        discipline_144.dig(disciplina, :peso) || 0
      end

      def peso_case_sql(discipline_col)
        cases = discipline_144.map do |disc, info|
          "WHEN #{discipline_col} = '#{disc}' THEN #{info[:peso]}"
        end
        "CASE #{cases.join(' ')} ELSE 0 END"
      end

      def where_clause(discipline_col, classe_col)
        names_sql = discipline_names.map { |d| "'#{d}'" }.join(", ")
        "#{classe_col} IN ('1', '4') AND #{discipline_col} IN (#{names_sql})"
      end

      def reset!
        @discipline_144 = nil
      end

      private

      def load_from_prezzi_ministeriali
        rows = PrezzoMinisteriale.correnti.where(classe: CLASSI_144)
        result = {}

        rows.each do |row|
          next unless row.disciplina.match?(DISCIPLINE_PATTERN)

          peso = row.disciplina.match?(FASCICOLO_PATTERN) ? 0.5 : 1.0

          result[row.disciplina] = {
            classe: row.classe,
            peso: peso,
            prezzo_cents: row.prezzo_cents
          }
        end

        result.freeze
      end
    end
  end
end
