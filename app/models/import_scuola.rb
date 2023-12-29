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

  scope :elementari, -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE"]) }
  scope :medie,      -> { where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE"]) }
  scope :superiori,  -> { where.not(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: ["SCUOLA PRIMO GRADO", "SCUOLA SEC. PRIMO GRADO NON STATALE", "SCUOLA PRIMARIA", "SCUOLA PRIMARIA NON STATALE", "SCUOLA INFANZIA NON STATALE", "SCUOLA INFANZIA", "ISTITUTO COMPRENSIVO"]) }
  

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

  def adozioni_grouped_classe 
    temp_group = import_adozioni.group_by {|k| [k.ANNOCORSO, k.COMBINAZIONE, k.CODICEISBN] }
    group = []
    temp_group.map do |k, v|
      sezioni = []
      v.each do |adozione|
        sezioni << adozione.SEZIONEANNO
      end    
      group << { anno: k[0][0], sezioni: sezioni.sort.join, combinazione: k[1], adozioni: v }
    end
    elenco = []
    elenco = group.group_by {|k| [k[:anno], k[:sezioni], k[:combinazione]]}
  end

  def self.prova 
    grouped = ImportScuola
                  .find_by_CODICESCUOLA("REEE81101E")
                  .import_adozioni
                  .group_by {|k| [k.ANNOCORSO, k.COMBINAZIONE, k.CODICEISBN]}
    group = []
    grouped.map do |k, v| 
      sezioni = []
      v.each do |adozione|
        sezioni << adozione.SEZIONEANNO
      end
      group << { anno: k[0][0], sezioni: sezioni.sort.join, combinazione: k[1], adozioni: v }
    end
    elenco = group.group_by {|k| [k[:anno], k[:sezioni], k[:combinazione]]}
    elenco

  end

end
