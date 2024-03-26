#https://bhserna.com/simple-searchable-module-for-searching-with-rails-and-sqlite-like

module Searchable
  extend ActiveSupport::Concern

  included do
    cattr_accessor :searchable_fields, :searchable_associations_fields
  end

  class_methods do
    def search_on(*searchable_fields, **searchable_associations_fields)
      self.searchable_fields = searchable_fields
      self.searchable_associations_fields = searchable_associations_fields

      # scope :search, ->(query) do
      #   joins(searchable_joins).where(searchable_where_clause, query: "%#{query}%")
      # end

      scope :left_search, ->(query) do
        left_joins(searchable_joins).where(searchable_where_clause, query: "%#{query}%")
      end

      scope :maybe_search, ->(query) do
        left_search(query) if query.present?
      end
    end

    def searchable_joins
      searchable_associations_fields.keys
    end

    def searchable_where_clause
      all_normalized_searchable_fields.map { |field| "#{field} ILIKE :query" }.join(" OR ")
    end

    def all_normalized_searchable_fields
      normalized_searchable_fields + normalized_searchable_associations_fields
    end
    
    # double quotes obbligatoria per i nomi dei campi in MAIUSCOLO
    def normalized_searchable_fields
      searchable_fields.map { |field| [table_name, "\"#{field}\""].join(".") }
    end

    def normalized_searchable_associations_fields
      searchable_associations_fields.flat_map do |association, fields|
        table_name = reflect_on_association(association).klass.table_name
        Array.wrap(fields).map { |field| [table_name, "\"#{field}\""].join(".") }
      end
    end
  end
end