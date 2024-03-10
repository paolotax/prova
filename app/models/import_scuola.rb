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

  has_many :plessi, class_name: "ImportScuola",
                          primary_key: "CODICESCUOLA",   
                          foreign_key: "CODICEISTITUTORIFERIMENTO"
                           
  belongs_to :direzione, class_name: "ImportScuola", optional: true
  
  
  has_many :import_adozioni, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"
  
  has_many :user_scuole
  has_many :users, through: :user_scuole

  has_many :appunti
  has_many :tappe, as: :tappable
  
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

  scope :dell_emilia_romagna , -> { where(REGIONE: "EMILIA ROMAGNA") }
  scope :di_parma,    -> { where(PROVINCIA: "PARMA") }
  scope :di_modena,   -> { where(PROVINCIA: "MODENA") }
  scope :di_bologna,  -> { where(PROVINCIA: "BOLOGNA") }
  scope :di_ferrara,  -> { where(PROVINCIA: "FERRARA") }
  scope :di_ravenna,  -> { where(PROVINCIA: "RAVENNA") }
  scope :di_forli_cesena,    -> { where(PROVINCIA: "FORLI' - CESENA") }
  scope :di_rimini,   -> { where(PROVINCIA: "RIMINI") }
  scope :di_piacenza, -> { where(PROVINCIA: "PIACENZA") }
  scope :di_fidenza,  -> { where(PROVINCIA: "PARMA").where("DESCRIZIONECOMUNE LIKE ?", "%FIDENZA%") }
  scope :di_cesena,   -> { where(PROVINCIA: "FORLI' - CESENA").where("DESCRIZIONECOMUNE LIKE ?", "%CESENA%") }
  scope :di_forli,    -> { where(PROVINCIA: "FORLI' - CESENA").where("DESCRIZIONECOMUNE LIKE ?", "%FORLI'%") }

  scope :di_reggio,  -> { where(PROVINCIA: "REGGIO EMILIA") }

  scope :elementari, -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "ISTITUTO COMPRENSIVO"]) }
  scope :medie,      -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE"]) }
  scope :superiori,  -> { where.not(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE", "SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "SCUOLA INFANZIA NON STATALE", "SCUOLA INFANZIA", "ISTITUTO COMPRENSIVO"]) }
  
  scope :della_regione, -> (regione) { where(REGIONE: regione) }
  scope :della_provincia, -> (provincia) { where(PROVINCIA: provincia) }
  scope :dell_area_geografica, -> (area) { where(AREAGEOGRAFICA: area) }
  scope :del_comune, -> (comune) { where(DESCRIZIONECOMUNE: comune) }

  scope :per_comune_e_direzione, -> { order([:DESCRIZIONECOMUNE, :CODICEISTITUTORIFERIMENTO, :CODICESCUOLA])}

  def to_s  
    ApplicationController.helpers.titleize_con_apostrofi(self.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA.titleize + " " + self.DENOMINAZIONESCUOLA + " - " + self.DESCRIZIONECOMUNE)
  end

  def adozioni 
    import_adozioni
  end
  
  def adozioni_count
    adozioni.size
  end

  def classi 
    import_adozioni.pluck(:ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE ).uniq
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

  def mie_adozioni(user_editori = [])
    import_adozioni.mie_adozioni(user_editori)
  end


  def adozioni_grouped_classe 
    grouped = import_adozioni.order([:ANNOCORSO, :COMBINAZIONE, :CODICEISBN]).group_by {|k| [k.ANNOCORSO, k.COMBINAZIONE, k.CODICEISBN] }
    temp = []
    grouped.each do |k, v| 
      sezioni = v.map { |a| a.SEZIONEANNO.titleize }.sort.join
      titolo  = v.map { |a| a.TITOLO }.uniq
      editore = v.map { |a| a.EDITORE }.uniq
      temp << { sezioni: "#{ k[0][0]} #{sezioni} - #{k[1].downcase}", titolo: titolo, editore: editore}
    end
    elenco = temp.group_by {|k| k[:sezioni]}
  end

  def adozioni_grouped_titolo 
    grouped = import_adozioni.order([:ANNOCORSO, :COMBINAZIONE, :CODICEISBN]).group_by {|k| [k.ANNOCORSO, k.COMBINAZIONE, :CODICEISBN ] }
    temp = []
    grouped.each do |k, v| 
      sezioni = v.map { |a| a.SEZIONEANNO.titleize }.sort.join(" ")
      titolo  = v.map { |a| a.TITOLO }.uniq
      editore = v.map { |a| a.EDITORE }.uniq
      disciplina = v.map { |a| a.DISCIPLINA }.uniq
      temp << { sezioni: "#{ k[0][0]} #{sezioni} - #{k[1].downcase}", titolo: titolo, editore: editore, disciplina: disciplina}
    end
    elenco = temp.group_by {|k| k[:sezioni]}
  end
  
  def self.prova 
    grouped = ImportScuola
                  .find_by_CODICESCUOLA("REEE81101E")
                  .import_adozioni
                  .group_by {|k| [k.ANNOCORSO, k.COMBINAZIONE, k.CODICEISBN]}
    temp = []
    grouped.each do |k, v| 
      sezioni = v.map { |a| a.SEZIONEANNO }.sort.join
      titoli  = v.map { |a| a.TITOLO }.uniq
      
      temp << { sezioni: "#{ k[0][0]} #{sezioni} - #{k[1]}", titoli: titoli}
    end
    elenco = temp.group_by {|k| k[:sezioni]}
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

  def self.tipi_scuole 
    self.pluck([:DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :DESCRIZIONECARATTERISTICASCUOLA])
                .uniq
                .sort_by{|k| [k[0], k[1]]}
  end

  scope :del_tipo_scuola, -> (tipo_scuola) { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipo_scuola)}

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


  def scuola 
    ApplicationController.helpers.titleize_con_apostrofi self.DENOMINAZIONESCUOLA
  end

  def citta
    ApplicationController.helpers.titleize_con_apostrofi self.DESCRIZIONECOMUNE
  end

  def tipo_scuola
    ApplicationController.helpers.titleize_con_apostrofi self.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA
  end

  def to_combobox_display
      self.scuola + " -> " + self.citta
  end

  def combinazioni
    self.import_adozioni.pluck(:COMBINAZIONE).uniq
      .sort.map { |c| c.gsub(/TEMPO PIENO/, 'T.P.').gsub(/ A /, ' ').gsub(/ A /, ' ').gsub(/SETTIMANALI/, ' ').downcase }.join(" - ")

  end
  
end
