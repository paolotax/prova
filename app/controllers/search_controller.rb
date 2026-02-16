class SearchController < ApplicationController
  layout false
  SEARCHABLES = {
    scuole:    { search: :search_all_word, label: "Scuole",    icon: "building-library" },
    libri:     { search: :search_all_word, label: "Libri",     icon: "book" },
    clienti:   { search: :search_all_word,  label: "Clienti",   icon: "users" },
    persone:   { search: :ilike_search,    label: "Persone",   icon: "user" },
    appunti:   { search: :search_appunti,  label: "Appunti",   icon: "note" },
    classi:    { search: :search_all_word, label: "Classi",    icon: "academic-cap" },
    documenti: { search: :search_docs,     label: "Documenti", icon: "document" }
  }.freeze

  def show
    return head(:no_content) if params[:q].blank? || params[:q].length < 2

    @results = SEARCHABLES.filter_map do |key, config|
      records = Current.account.public_send(key)
                  .public_send(config[:search], params[:q])
                  .limit(6)
      next if records.empty?

      { key:, records:, **config }
    end
  end
end
