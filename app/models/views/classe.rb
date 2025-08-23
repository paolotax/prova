# == Schema Information
#
# Table name: view_classi
#
#  id                  :integer          primary key
#  area_geografica     :string
#  regione             :string
#  provincia           :string
#  codice_ministeriale :string
#  classe              :string
#  sezione             :string
#  combinazione        :string
#  import_adozioni_ids :integer          is an Array
#  anno                :string
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

  self.primary_key = "id"

  # self.primary_key = [
  #     "codice_ministeriale",
  #     "classe",
  #     "sezione",
  #     "combinazione"
  # ]

  has_many :import_adozioni, 
          primary_key: [:codice_ministeriale, :classe, :sezione, :combinazione],
          foreign_key: [:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE]
          
  belongs_to :import_scuola, foreign_key: "codice_ministeriale", primary_key: "CODICESCUOLA"

  has_many :adozioni  # dovrò chiamare la tabella in altro modo movimenti o righe e cambiare stato_adozione in tipo_movimento
  has_many :vendita, -> { vendita }, class_name: "Adozione"
  has_many :omaggio, -> { omaggio }, class_name: "Adozione"
  has_many :adozione, -> { adozione }, class_name: "Adozione"
  
  has_many :appunti # dovrò METTERE SOLO QUELLI DELL USER LOGGATO
  
  
  scope :prime, -> { where(classe: "1") }
  scope :seconde, -> { where(classe: "2") }
  scope :terze, -> { where(classe: "3") }
  scope :quarte, -> { where(classe: "4") }
  scope :quinte, -> { where(classe: "5") }

  scope :classe_che_adotta, -> { where(classe: [3, 5]) }
  scope :tempo_pieno, -> { where("view_classi.combinazione like ?", "%40 ORE%") }

  delegate :tipo_scuola, :nome_scuola, :citta_scuola, to: :import_scuola, allow_nil: true
  
  def classe_e_sezione
    "#{classe} #{sezione.titleize}"
  end

  def to_combobox_display
    "#{classe} #{sezione.titleize}"
  end

  def readonly?
    true
  end

  def libro_ids
    adozioni.map(&:libro_id)
  end

  def maestre
    adozioni.map(&:maestre).flatten.uniq.sort
  end

end
