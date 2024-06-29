# == Schema Information
#
# Table name: new_adozioni
#
#  id               :bigint           not null, primary key
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
