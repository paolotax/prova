module Filters
  module AppuntoFilterScopes
    extend FilterScopeable

    # We define scopes with out new method
    filter_scope :stato, ->(stato) { where(stato: stato) }
    filter_scope :statuses, ->(stato) { where(stato: stato) }
    
    filter_scope :archiviati, ->(archiviati) { archiviati == "si" ? where(stato: "archiviato") : all }
    
    filter_scope :del_giorno, ->(giorno) {
      da_completare
      .nel_baule_del_giorno(giorno)
      .with_attached_attachments
      .with_attached_image
      .with_rich_text_content
      .includes(:import_scuola) 
    }

    filter_scope :search, ->(search) { search_all_word(search) }
  end

  class AppuntoFilterProxy < FilterProxy
    def self.query_scope = Appunto
    def self.filter_scopes_module = Filters::AppuntoFilterScopes
  end
end