# == Schema Information
#
# Table name: new_adozioni
#
#  id               :bigint           primary key
#  anno_scolastico  :string
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

class NewAdozione < ApplicationRecord
    # new_adozioni e' una vista ponte su miur_adozioni (anno corrente):
    # le viste non dichiarano PK, quindi va esplicitata. anno_scolastico
    # e' la chiave di partizione: default per i writer legacy che non
    # lo valorizzavano (la tabella swing lo lasciava NULL) — l'anno
    # dell'anagrafe scuole, cioe' quello che la vista ponte rende visibile.
    self.primary_key = "id"
    self.sequence_name = "miur_adozioni_id_seq"
    attribute :anno_scolastico, :string, default: -> { Miur.anno_corrente || "202627" }

    #belongs_to :import_scuola, class_name: 'Import::Scuola', foreign_key: 'import_scuola_id'
    validates :codicescuola, :annocorso, :sezioneanno, :combinazione, :codiceisbn, presence: true
    validates :codicescuola, uniqueness: { scope: [:anno_scolastico, :annocorso, :sezioneanno, :combinazione, :codiceisbn, :disciplina] }
    
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

    def self.assign_from_row(row)
        new_adozione = NewAdozione.where(
            codicescuola: row[:codicescuola], 
            annocorso: row[:annocorso],
            sezioneanno: row[:sezioneanno],
            combinazione: row[:combinazione],
            codiceisbn: row[:codiceisbn]
        ).first_or_initialize
        new_adozione.assign_attributes row.to_hash
        new_adozione
    end
end
