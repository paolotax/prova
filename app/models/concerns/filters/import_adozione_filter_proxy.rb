module Filters
  module ImportAdozioneFilterScopes
    extend FilterScopeable

    # We define scopes with out new method    
    
    filter_scope :titolo, ->(name) { where('import_adozioni."TITOLO" ILIKE ?', "%#{name}%") }
    filter_scope :editore, ->(name) { where('import_adozioni."EDITORE" ILIKE ?', "%#{name}%") }
    filter_scope :disciplina, ->(name) { where('import_adozioni."DISCIPLINA" IN (?)', name) }
    filter_scope :codice_isbn, ->(isbn) { where('import_adozioni."CODICEISBN" ILIKE ?', "%#{isbn}%") }
    filter_scope :classe, ->(classe) { where(ANNOCORSO: classe) }

    filter_scope :codice_scuola, ->(codice) { joins(:import_scuola).where('import_scuole."CODICESCUOLA" ILIKE ?', "%#{codice}%") }
    filter_scope :comune, ->(comune) { joins(:import_scuola).where('import_scuole."DESCRIZIONECOMUNE" ILIKE ?', "%#{comune}%") }
    filter_scope :scuola, ->(denominazione) { joins(:import_scuola).where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ?', "%#{denominazione}%") }

    filter_scope :mie_adozioni, ->  (q) { q == "si" ? where(EDITORE: Current.user.miei_editori) : all  }
    filter_scope :da_acquistare, -> (q) { q == "si" ? where(DAACQUIST: "Si") : all }

    filter_scope :nel_baule, -> (q) { filter_nel_baule(q) }  
    def filter_nel_baule(quando)
      if quando == "oggi"
        where(CODICESCUOLA: ImportScuola.select(:CODICESCUOLA).distinct.where( id: Current.user.tappe.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id)))
      elsif quando == "domani"
        where(CODICESCUOLA: ImportScuola.select(:CODICESCUOLA).distinct.where( id: Current.user.tappe.di_domani.where(tappable_type: "ImportScuola").pluck(:tappable_id)))
      else
        all
      end
    end


    # filter_scope :per_scuola_classe_disciplina_sezione, -> { order( :CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :SEZIONEANNO) }
    
    # filter_scope :classi_che_adottano, -> { where(ANNOCORSO: [3, 5]) }
    
    #filter_scope :search, ->(search) { left_search

  end

  class ImportAdozioneFilterProxy < FilterProxy
    def self.query_scope = ImportAdozione
    def self.filter_scopes_module = Filters::ImportAdozioneFilterScopes
  end
end