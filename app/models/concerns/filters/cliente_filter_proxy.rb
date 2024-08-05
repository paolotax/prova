module Filters
  module ClienteFilterScopes
    extend FilterScopeable

    # We define scopes with out new method
    filter_scope :ragione_sociale, ->(name) { where("denominazione ILIKE ?", "%#{name}%") }
    filter_scope :comune, ->(name) { where("comune ILIKE ?", "%#{name}%") }
    filter_scope :partita_iva, ->(name) { where("partita_iva ILIKE ?", "%#{name}%") }
    filter_scope :status, ->(status) { where(status: status) }

    filter_scope :search, ->(search) { left_search(search) }
  end

  class ClienteFilterProxy < FilterProxy
    def self.query_scope = Cliente
    def self.filter_scopes_module = Filters::ClienteFilterScopes
  end
end