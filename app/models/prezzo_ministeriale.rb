# == Schema Information
#
# Table name: prezzi_ministeriali
#
#  id               :uuid             not null, primary key
#  anno_scolastico  :string           not null
#  classe           :string           not null
#  disciplina       :string           not null
#  prezzo_cents     :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  idx_prezzi_min_anno_classe_disc  (anno_scolastico,classe,disciplina) UNIQUE
#
class PrezzoMinisteriale < ApplicationRecord
  self.table_name = "prezzi_ministeriali"

  monetize :prezzo_cents

  validates :anno_scolastico, :classe, :disciplina, :prezzo_cents, presence: true
  validates :disciplina, uniqueness: { scope: [:anno_scolastico, :classe] }

  scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
  scope :correnti, -> { per_anno(anno_corrente) }

  # { "1" => ["IL LIBRO DELLA PRIMA CLASSE", ...], "4" => ["SUSSIDIARIO DEI LINGUAGGI", ...] }
  def self.discipline_per_classe(anno: nil)
    anno ||= anno_corrente
    return {} unless anno

    per_anno(anno).order(:classe, :disciplina)
                  .group_by(&:classe)
                  .transform_values { |v| v.map(&:disciplina) }
  end

  def self.anno_corrente
    order(anno_scolastico: :desc).pick(:anno_scolastico)
  end

  def self.prezzo_per(classe:, disciplina:, anno: nil)
    anno ||= anno_corrente
    find_by(anno_scolastico: anno, classe: classe, disciplina: disciplina)&.prezzo_cents
  end

  def self.popola_da_import_adozioni!(anno_scolastico:, tipogrado: "EE")
    sql = <<~SQL
      WITH prezzi AS (
        SELECT "ANNOCORSO" as classe,
               "DISCIPLINA" as disciplina,
               ROUND(REPLACE("PREZZO", ',', '.')::numeric * 100)::integer as prezzo_cents,
               COUNT(*) as freq
        FROM import_adozioni
        WHERE "TIPOGRADOSCUOLA" = #{connection.quote(tipogrado)}
          AND "PREZZO" IS NOT NULL
          AND "PREZZO" != ''
          AND REPLACE("PREZZO", ',', '.') ~ '^\\d+(\\.\\d+)?$'
        GROUP BY "ANNOCORSO", "DISCIPLINA", ROUND(REPLACE("PREZZO", ',', '.')::numeric * 100)::integer
      ),
      ranked AS (
        SELECT classe, disciplina, prezzo_cents, freq,
               ROW_NUMBER() OVER (PARTITION BY classe, disciplina ORDER BY freq DESC) as rn,
               SUM(freq) OVER (PARTITION BY classe, disciplina) as totale
        FROM prezzi
      )
      SELECT classe, disciplina, prezzo_cents, freq, totale
      FROM ranked
      WHERE rn = 1
        AND totale > 100
        AND freq::float / totale::float > 0.9
      ORDER BY classe::int, totale DESC
    SQL

    results = connection.execute(sql)
    count = 0

    transaction do
      results.each do |row|
        record = find_or_initialize_by(
          anno_scolastico: anno_scolastico,
          classe: row["classe"],
          disciplina: row["disciplina"]
        )
        record.update!(prezzo_cents: row["prezzo_cents"])
        count += 1
      end
    end

    count
  end
end
