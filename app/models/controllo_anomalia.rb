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
