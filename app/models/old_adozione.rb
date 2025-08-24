# == Schema Information
#
# Table name: old_adozioni
#
#  id               :integer          not null, primary key
#  codicescuola     :string
#  annocorso        :string
#  sezioneanno      :string
#  tipogradoscuola  :string
#  combinazione     :string
#  disciplina       :string
#  codiceisbn       :string
#  autori           :string
#  titolo           :string
#  sottotitolo      :string
#  volume           :string
#  editore          :string
#  prezzo           :string
#  nuovaadoz        :string
#  daacquist        :string
#  consigliato      :string
#  anno_scolastico  :string
#  import_scuola_id :integer
#
# Indexes
#
#  index_old_adozioni_on_classe  (anno_scolastico,codicescuola,annocorso,sezioneanno,combinazione,codiceisbn) UNIQUE
#

class OldAdozione < ApplicationRecord
    
    #belongs_to :import_scuola, class_name: 'Import::Scuola', foreign_key: 'import_scuola_id'
    validates :codicescuola, :annocorso, :sezioneanno, :combinazione, :codiceisbn, presence: true
    validates :codicescuola, uniqueness: { scope: [:annocorso, :sezioneanno, :combinazione, :codiceisbn] }
    
    def self.assign_from_row(row)
        old_adozione = OldAdozione.where(
            codicescuola: row[:codicescuola], 
            annocorso: row[:annocorso],
            sezioneanno: row[:sezioneanno],
            combinazione: row[:combinazione],
            codiceisbn: row[:codiceisbn]
        ).first_or_initialize
        old_adozione.assign_attributes row.to_hash
        old_adozione
    end
end
