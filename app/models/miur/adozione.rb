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
  scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
  scope :correnti, -> { per_anno(Miur.anno_corrente) }

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
