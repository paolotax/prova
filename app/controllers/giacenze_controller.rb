class GiacenzeController < ApplicationController
  include FilterScoped
  include HasVista

  FILTER_PARAMS = [:anno, stati: [], editori: [], categorie: [], terms: []].freeze

  before_action :authenticate_user!

  ORDINE_DEFAULT = "libri.titolo ASC".freeze

  def index
    @columns = resolve_colonne(Giacenza::Columns)
    @sort = resolve_sort(@columns)

    scope = @filter.libri.includes(:editore)
    scope_totali = @filter.libri(ignora_stati: true)

    @totali = totali(scope_totali)
    @total_count = scope.except(:select).count

    # Alcuni scope (in particolare pg_search) hanno gia' un ORDER BY: va
    # sostituito, non accodato, altrimenti la scelta dell'utente e' secondaria.
    scope = @sort.active? ? apply_sort(scope, @sort) : scope.reorder(Arel.sql(ORDINE_DEFAULT))
    set_page_and_extract_portion_from scope
  end

  private

    def totali(scope)
      colonne = %w[campionario scarico_saggi venduti da_consegnare venduto_cents]
      row = scope.except(:select).reorder(nil).pick(
        Arel.sql("COALESCE(SUM(libri.adozioni_count), 0)"),
        *colonne.map { |c| Arel.sql("COALESCE(SUM(conteggi.#{c}), 0)") }
      )
      %i[adottati campionario scarico_saggi venduti da_consegnare venduto_cents].zip(row.map(&:to_i)).to_h
    end
end
