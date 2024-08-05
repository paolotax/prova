module Filters
  module ClienteFilterScopes
    extend FilterScopeable

    # We define scopes with out new method
    filter_scope :cliente, ->(name) { where("denominazione ILIKE ?", "%#{name}%") }
    filter_scope :comune, ->(name) { where("comune ILIKE ?", "%#{name}%") }
    filter_scope :status, ->(status) { where(status:) }

    filter_scope :search, ->(search) { left_search(search) }
  end

  class ClienteFilterProxy < FilterProxy
    def self.query_scope = Cliente
    def self.filter_scopes_module = Filters::ClienteFilterScopes
  end
end