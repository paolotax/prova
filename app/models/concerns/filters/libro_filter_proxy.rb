module Filters
  module LibroFilterScopes
    extend FilterScopeable

    # We define scopes with out new method
    filter_scope :titolo, ->(name) { where("libri.titolo ILIKE ?", "%#{name}%") }
    filter_scope :disciplina, ->(name) { where("libri.disciplina ILIKE ?", "%#{name}%") }
    filter_scope :categoria, ->(name) { where("libri.categoria ILIKE ?", "%#{name}%") }
    filter_scope :editore, ->(name) { joins(:editore).where("editori.editore ILIKE ?", "%#{name}%") }
    filter_scope :classe, ->(classe) { where(classe: classe) }
    
    filter_scope :ordini, ->(ordini) { joins(:giacenza).where("view_giacenze.ordini > ?", ordini) }
    
    filter_scope :incompleti, ->(incompleti) { incompleti == "si" ? where("libri.editore_id IS NULL OR libri.categoria IS NULL") : all }
    
    filter_scope :search, ->(search) { search_all_word(search) }
  end

  class LibroFilterProxy < FilterProxy
    def self.query_scope = Libro
    def self.filter_scopes_module = Filters::LibroFilterScopes
  end
end