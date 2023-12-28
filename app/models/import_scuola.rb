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

  has_many :import_adozioni, foreign_key: "CODICESCUOLA", primary_key: "CODICESCUOLA"
  
  include PgSearch::Model

  search_fields =  [ :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA ]

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


  scope :di_reggio,  -> { where(PROVINCIA: "REGGIO EMILIA") }

  scope :elementari, -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE"]) }
  scope :medie,     -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE"]) }
  scope :superiori, -> { where.not(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE", "SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "SCUOLA INFANZIA NON STATALE", "SCUOLA INFANZIA", "ISTITUTO COMPRENSIVO"]) }
  

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
    classi.count
  end

  def marchi
    import_adozioni.pluck(:EDITORE).uniq
  end

  def marchi_count
    marchi.count
  end

end
