class SearchController < ApplicationController
  layout false
  SEARCHABLES = {
    scuole:    { search: :search_all_word, label: "Scuole",    icon: "building-library" },
    libri:     { search: :search_all_word, label: "Libri",     icon: "book" },
    clienti:   { search: :left_search,     label: "Clienti",   icon: "users" },
    documenti: { search: :search_docs,     label: "Documenti", icon: "document" },
    appunti:   { search: :search_appunti,  label: "Appunti",   icon: "note" },
    classi:    { search: :search_all_word, label: "Classi",    icon: "academic-cap" },
    persone:   { search: :ilike_search,    label: "Persone",   icon: "user" },
  }.freeze

  FIXED_ORDER = %i[scuole libri clienti documenti appunti classi persone].freeze

  def show
    return head(:no_content) if params[:q].blank? || params[:q].length < 2

    @results = ordered_keys.filter_map do |key|
      config = SEARCHABLES[key]
      records = Current.account.public_send(key)
                  .public_send(config[:search], params[:q])
                  .limit(6)
      next if records.empty?

      { key:, records:, **config }
    end
  end

  private

  def ordered_keys
    context = params[:context]&.to_sym
    return FIXED_ORDER unless context && SEARCHABLES.key?(context)

    [context] + (FIXED_ORDER - [context])
  end
end
