module Filters
  module LibroFilterScopes
    extend FilterScopeable

    # We define scopes with out new method
    filter_scope :titolo, ->(name) { where("libri.titolo ILIKE ?", "%#{name}%") }
    filter_scope :disciplina, ->(name) { where("libri.disciplina ILIKE ?", "%#{name}%") }
    filter_scope :categoria, ->(name) { where("libri.categoria ILIKE ?", "%#{name}%") }
    filter_scope :editore, ->(name) { joins(:editore).where("editori.editore ILIKE ?", "%#{name}%") }
    filter_scope :classe, ->(classe) { where(classe: classe) }
    
    filter_scope :fascicoli, ->(confezione_id) { where(id: ConfezioneRiga.where(confezione_id: confezione_id).pluck(:fascicolo_id).uniq.unshift(confezione_id)) }
    filter_scope :confezioni, ->(fascicolo_id) { where(id: ConfezioneRiga.where(fascicolo_id: fascicolo_id).select(:confezione_id)) }
    
    filter_scope :ordini, ->(ordini) { joins(:giacenza).where("view_giacenze.ordini > ?", ordini) }
    
    filter_scope :incompleti, ->(incompleti) { incompleti == "si" ? where("libri.editore_id IS NULL OR libri.categoria IS NULL") : all }
    
    filter_scope :search, ->(search) { search_all_word(search) }
  end

  class LibroFilterProxy < FilterProxy
    def self.query_scope = Libro
    def self.filter_scopes_module = Filters::LibroFilterScopes
  end
end