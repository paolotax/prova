# miur_adozioni e' partizionata per LIST (anno_scolastico) con PK composita
# (anno_scolastico, id): le righe vanno INSERITE sempre attraverso la tabella
# padre miur_adozioni, mai direttamente in una partizione (le partizioni PG15
# non ereditano la generazione identity dell'id).
# I lookup per id vanno sempre scopati anche su anno_scolastico: gli id NON
# sono globalmente unici tra le partizioni (il backfill preserva gli id originali).
# == Schema Information
#
# Table name: miur_adozioni
#
#  id               :bigint           not null, primary key
#  anno_scolastico  :string           not null, primary key
#  annocorso        :string
#  autori           :string
#  codiceisbn       :string
#  codicescuola     :string
#  combinazione     :string
#  consigliato      :string
#  daacquist        :string
#  disciplina       :string
#  editore          :string
#  nuovaadoz        :string
#  prezzo           :string
#  sezioneanno      :string
#  sottotitolo      :string
#  tipogradoscuola  :string
#  titolo           :string
#  volume           :string
#  import_scuola_id :bigint
#
# Indexes
#
#  idx_miur_adoz_ee                (codicescuola) WHERE ((tipogradoscuola)::text = 'EE'::text)
#  idx_miur_adozioni_codicescuola  (codicescuola)
#  idx_miur_adozioni_disc_anno_tg  (disciplina,annocorso,tipogradoscuola)
#  index_miur_adozioni_on_classe   (anno_scolastico,codicescuola,annocorso,sezioneanno,combinazione,codiceisbn,disciplina) UNIQUE
#
class Miur::Adozione < ApplicationRecord
  # Anagrafe della scuola per codice ministeriale. Le partizioni storiche
  # (es. 202526) non hanno import_scuola_id popolato: il join durevole e'
  # sul codicescuola (come faceva ImportAdozione).
  belongs_to :import_scuola, class_name: "ImportScuola",
                             foreign_key: :codicescuola, primary_key: "CODICESCUOLA",
                             optional: true

  scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
  scope :correnti, -> { per_anno(Miur.anno_corrente) }

  # Testi EE di religione/alternativa negli anni "di mezzo" dei volumi
  # pluriennali (2ª-3ª sul vol. 1-2-3, 5ª sul vol. 4-5): il MIUR li pubblica
  # con DAACQUIST=Si ma il volume e' gia' posseduto dall'anno d'acquisto —
  # vanno normalizzati a No (miur:cambia_religione + staging di
  # miur:importa_adozioni). Le grafie con spazio finale sono reali nei CSV.
  RELIGIONE_EE_ANNI = %w[2 3 5].freeze
  RELIGIONE_EE_DISCIPLINE = [
    "RELIGIONE",
    "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94",
    "ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94 ",
    "RELIGIONE CATTOLICA/ATTIVITA' ALTERNATIVA",
    "RELIGIONE CATTOLICA/ATTIVITA' ALTERNATIVA ",
  ].freeze

  scope :religione_ee_da_normalizzare, -> {
    where(tipogradoscuola: "EE", annocorso: RELIGIONE_EE_ANNI, disciplina: RELIGIONE_EE_DISCIPLINE)
  }

  # Adozioni degli editori sotto mandato dell'account corrente (ex
  # ImportAdozione.mie_adozioni, che filtrava per Current.user.miei_editori).
  scope :mie_adozioni, -> {
    where(editore: Current.account.mandati.joins(:editore).select("editori.editore"))
  }

  # Disciplina esclusa dal totale spesa e dal confronto col tetto ministeriale,
  # pur restando visibile nell'elenco: alternativa alla religione (mutuamente
  # esclusiva con religione) e parascolastica (libri facoltativi).
  def escluso_dal_tetto?
    disciplina.to_s.match?(/\A(ADOZIONE ALTERNATIVA|PARASCOLASTIC)/i)
  end

  # Prezzo (stringa "12,34") convertito in euro come BigDecimal, nil se non numerico.
  def prezzo_euro
    normalizzato = prezzo.to_s.tr(",", ".")
    return unless normalizzato.match?(/\A[0-9]+(\.[0-9]+)?\z/)
    BigDecimal(normalizzato)
  end
end
