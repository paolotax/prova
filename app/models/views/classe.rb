# == Schema Information
#
# Table name: view_classi
#
#  id                  :bigint
#  anno                :text
#  area_geografica     :string
#  classe              :string
#  codice_ministeriale :string
#  combinazione        :string
#  import_adozioni_ids :bigint           is an Array
#  provincia           :string
#  regione             :string
#  sezione             :string
#
# Indexes
#
#  idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec  (codice_ministeriale,classe,sezione,combinazione) UNIQUE
#  index_view_classi_on_codice_ministeriale                        (codice_ministeriale)
#  index_view_classi_on_provincia                                  (provincia)
#




# Adozione.where(classe_id: nil).each do |a|
#     unless a.import_adozione.nil?
#     a.classe_id = a.import_adozione.classe.attributes['id']
#     a.save
#   end
# end


class Views::Classe < ApplicationRecord

    #self.primary_key = "id"

    self.primary_key = [
        "codice_ministeriale",
        "classe",
        "sezione",
        "combinazione"
    ]

    has_many :import_adozioni, query_constraints: [
        :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE
    ]

    belongs_to :import_scuola, foreign_key: "codice_ministeriale", primary_key: "CODICESCUOLA"
 
    has_many :adozioni



    scope :prime, -> { where(classe: "1") }
    scope :seconde, -> { where(classe: "2") }
    scope :terze, -> { where(classe: "3") }
    scope :quarte, -> { where(classe: "4") }
    scope :quinte, -> { where(classe: "5") }

    scope :classe_che_adotta, -> { where(classe: [3, 5]) }

    scope :tempo_pieno, -> { where("view_classi.combinazione like ?", "%40 ORE%") }

    def to_combobox_display
    "#{classe} #{sezione} - #{combinazione.downcase}"
    end

    def readonly?
        true
    end
end
