# == Schema Information
#
# Table name: import_scuole
#
#  id                                        :bigint           not null, primary key
#  ANNOSCOLASTICO                            :string
#  AREAGEOGRAFICA                            :string
#  REGIONE                                   :string
#  PROVINCIA                                 :string
#  CODICEISTITUTORIFERIMENTO                 :string
#  DENOMINAZIONEISTITUTORIFERIMENTO          :string
#  CODICESCUOLA                              :string
#  DENOMINAZIONESCUOLA                       :string
#  INDIRIZZOSCUOLA                           :string
#  CAPSCUOLA                                 :string
#  CODICECOMUNESCUOLA                        :string
#  DESCRIZIONECOMUNE                         :string
#  DESCRIZIONECARATTERISTICASCUOLA           :string
#  DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA :string
#  INDICAZIONESEDEDIRETTIVO                  :string
#  INDICAZIONESEDEOMNICOMPRENSIVO            :string
#  INDIRIZZOEMAILSCUOLA                      :string
#  INDIRIZZOPECSCUOLA                        :string
#  SITOWEBSCUOLA                             :string
#  SEDESCOLASTICA                            :string
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#
class ImportScuola < ApplicationRecord

  include Searchable

  search_on :CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO

  has_many :plessi, class_name: "ImportScuola",
                    primary_key: "CODICESCUOLA",   
                    foreign_key: "CODICEISTITUTORIFERIMENTO"
                           
  belongs_to :direzione, class_name: "ImportScuola", 
                         primary_key: "CODICESCUOLA",   
                         foreign_key: "CODICEISTITUTORIFERIMENTO", optional: true
  
  has_many :import_adozioni, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"
  
  has_many :user_scuole
  has_many :users, through: :user_scuole

  has_many :classi, class_name: "Views::Classe", foreign_key: "codice_ministeriale", primary_key: "CODICESCUOLA"

  has_many :appunti
  
  has_many :tappe, as: :tappable

  has_one :tipo_scuola, primary_key: "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA", foreign_key: "tipo"
  
  include PgSearch::Model

  search_fields =  [ :CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO ]

  pg_search_scope :search_all_word, 
                        against: search_fields,
                        using: {
                          tsearch: { any_word: false, prefix: true }
                        }

  pg_search_scope :search_any_word,
                          against: search_fields,
                          using: {
                            tsearch: { any_word: true, prefix: true }
                          } 

  scope :elementari, -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "ISTITUTO COMPRENSIVO"]) }
  scope :medie,      -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE"]) }
  scope :superiori,  -> { where.not(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE", "SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "SCUOLA INFANZIA NON STATALE", "SCUOLA INFANZIA", "ISTITUTO COMPRENSIVO"]) }
  
  scope :della_regione, -> (regione) { where(REGIONE: regione) }
  scope :della_provincia, -> (provincia) { where(PROVINCIA: provincia) }
  scope :dell_area_geografica, -> (area) { where(AREAGEOGRAFICA: area) }
  scope :del_comune, -> (comune) { where(DESCRIZIONECOMUNE: comune) }

  scope :per_comune_e_direzione, -> { order([:PROVINCIA, :DESCRIZIONECOMUNE, :CODICEISTITUTORIFERIMENTO, :CODICESCUOLA])}

  def to_s  
    ApplicationController.helpers.titleize_con_apostrofi(self.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA + " " + self.DENOMINAZIONESCUOLA + " - " + self.DESCRIZIONECOMUNE)
  end

  def direzione_or_privata
    self.direzione || "<privata>".html_safe
  end

  def adozioni 
    import_adozioni
  end
  
  def adozioni_count
    adozioni.size
  end

  def classi_count
    classi.size
  end

  def marchi
    import_adozioni.pluck(:EDITORE).uniq
  end

  def marchi_count
    marchi.size
  end

  def mie_adozioni
    import_adozioni.mie_adozioni
  end

  def self.zone
    self.pluck([:AREAGEOGRAFICA, :REGIONE, :PROVINCIA])
                .uniq
                .sort_by{|k| [k[0], k[1], k[2]]}
  end

  def self.di_zona(area: nil, regione: nil, provincia: nil)
    scoped = self
    scoped = scoped.della_regione(regione) if !regione.nil?
    scoped = scoped.della_provincia(provincia) if !provincia.nil?
    scoped = scoped.dell_area_geografica(area) if !area.nil?
    scoped
  end

  # def self.tipi_scuole 
  #   self.pluck([:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :DESCRIZIONECARATTERISTICASCUOLA])
  #               .uniq
  #               .sort_by{|k| [k[0], k[1]]}
  # end

  # scope :del_tipo_scuola, -> (tipo_scuola) { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipo_scuola)}

  def latitudine 
    44.70511452961794
  end

  def longitudine 
    10.643349039039835
  end

  def indirizzo
    "https://www.google.com/maps/search/?api=1&query=#{self.INDIRIZZOSCUOLA}+#{self.CAPSCUOLA}+#{self.DESCRIZIONECOMUNE}+#{self.PROVINCIA}"
     
    "https://waze.com/ul?q=66%20Acacia%20Avenue"
  
    [self.INDIRIZZOSCUOLA, self.CAPSCUOLA, self.DESCRIZIONECOMUNE, self.PROVINCIA].join(" ")
  end

  def codice_ministeriale
    self.CODICESCUOLA
  end

  def scuola 
    ApplicationController.helpers.titleize_con_apostrofi self.DENOMINAZIONESCUOLA
  end

  def citta
    #ApplicationController.helpers.titleize_con_apostrofi self.DESCRIZIONECOMUNE
    self.DESCRIZIONECOMUNE.upcase
  end

  def tipo_scuola
    ApplicationController.helpers.titleize_con_apostrofi self.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA
  end

  def tipo_nome
    ApplicationController.helpers.titleize_con_apostrofi [self.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, self.DENOMINAZIONESCUOLA].join(" ")
  end

  def to_combobox_display
      self.scuola + " -> " + self.citta
  end

  def combinazioni
    self.import_adozioni.pluck(:COMBINAZIONE).uniq
      .sort.map { |c| c.gsub(/TEMPO PIENO/, 'T.P.').gsub(/ A /, ' ').gsub(/ A /, ' ').gsub(/SETTIMANALI/, ' ').downcase }

  end

  def terze_e_quinte
    self.import_adozioni.where(ANNOCORSO: [ 3, 5 ])
                        .select(:ANNOCORSO, :SEZIONEANNO)
                        .distinct
                        .order(:ANNOCORSO, :SEZIONEANNO)
                        .map { |a| "#{a.ANNOCORSO}#{a.SEZIONEANNO}" }
  end


  def self.con_appunti(relation)
    ids = relation.pluck(:import_scuola_id).uniq
    ImportScuola.where('import_scuole.id in (?)', ids)
  end
  
end
