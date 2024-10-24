 module Filters
  module ImportScuolaFilterScopes
    extend FilterScopeable
 
    filter_scope :search, ->(search) { search_all_word(search) }
    filter_scope :nome, ->(nome) { where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ?', "%#{nome}%") }
    filter_scope :codice, ->(codice) { where('import_scuole."CODICESCUOLA" ILIKE ?', "%#{codice}%") }
    filter_scope :direzione, ->(direzione) { where('import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO" ILIKE ?', "%#{direzione}%") }
    filter_scope :codice_direzione, ->(codice) { where('import_scuole."CODICEISTITUTORIFERIMENTO" ILIKE ?', "%#{codice}%") }
    filter_scope :comune, ->(comune) { where('import_scuole."DESCRIZIONECOMUNE" ILIKE ?', "%#{comune}%") }
    
    filter_scope :con_appunti, -> (q) { filter_con_appunti(q) }    
    def filter_con_appunti(quali)
      if quali == "in sospeso"
        where(id: Current.user.appunti.in_sospeso.pluck(:import_scuola_id).uniq)
      elsif quali == "completati"
        where(id: Current.user.appunti.completati.pluck(:import_scuola_id).uniq)
      elsif quali == "da completare"
        where(id: Current.user.appunti.da_completare.pluck(:import_scuola_id).uniq)   
      else
        all
      end
    end

  end

  class ImportScuolaFilterProxy < FilterProxy
    def self.query_scope = ImportScuola
    def self.filter_scopes_module = Filters::ImportScuolaFilterScopes
  end
end