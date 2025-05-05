# == Schema Information
#
# Table name: new_adozioni
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
#  index_new_adozioni_on_classe  (anno_scolastico,codicescuola,annocorso,sezioneanno,combinazione,codiceisbn) UNIQUE
#

class NewAdozione < ApplicationRecord
    
    #belongs_to :import_scuola, class_name: 'Import::Scuola', foreign_key: 'import_scuola_id'
    validates :codicescuola, :annocorso, :sezioneanno, :combinazione, :codiceisbn, presence: true
    validates :codicescuola, uniqueness: { scope: [:annocorso, :sezioneanno, :combinazione, :codiceisbn] }
    
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
