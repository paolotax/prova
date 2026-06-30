# == Schema Information
#
# Table name: controllo_anomalie
#
#  id                  :uuid             not null, primary key
#  anno_scolastico     :string
#  annocorso           :string
#  codiceisbn          :string
#  codicescuola        :string           not null
#  combinazione        :string
#  comune              :string
#  delta_cents         :integer
#  denominazione       :string
#  dettaglio           :jsonb            not null
#  disciplina          :string
#  editore             :string
#  prezzo_atteso_cents :integer
#  prezzo_cents        :integer
#  provincia           :string
#  regione             :string
#  sezioneanno         :string
#  tipo                :string           not null
#  titolo              :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_controllo_anomalie_on_anno_scolastico_and_codicescuola  (anno_scolastico,codicescuola)
#  index_controllo_anomalie_on_codicescuola                      (codicescuola)
#  index_controllo_anomalie_on_provincia                         (provincia)
#  index_controllo_anomalie_on_tipo                              (tipo)
#
class ControlloAnomalia < ApplicationRecord
  self.table_name = "controllo_anomalie"

  TIPI = %w[
    prezzo_isbn prezzo_disciplina disciplina_mancante doppione tetto_superato scuola_mancante
  ].freeze

  validates :codicescuola, presence: true
  validates :tipo, presence: true, inclusion: { in: TIPI, message: "non incluso nell'elenco" }

  scope :per_anno,    ->(anno) { where(anno_scolastico: anno) }
  scope :per_tipo,    ->(tipo) { where(tipo: tipo) }
  scope :per_scuola,  ->(cod)  { where(codicescuola: cod) }
  scope :per_classe,  ->(cod, annocorso, sezioneanno, combinazione) {
    where(codicescuola: cod, annocorso: annocorso, sezioneanno: sezioneanno, combinazione: combinazione)
  }

  # Classifica scuole per numero di anomalie (decrescente), con i tipi distinti presenti.
  scope :classifica, -> {
    select("codicescuola, MAX(denominazione) AS denominazione, MAX(provincia) AS provincia, " \
           "MAX(comune) AS comune, COUNT(*) AS n_anomalie, " \
           "string_agg(DISTINCT tipo, ',' ORDER BY tipo) AS tipi")
      .group(:codicescuola)
      .order(Arel.sql("COUNT(*) DESC"))
  }
end
