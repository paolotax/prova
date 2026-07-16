class GiacenzeController < ApplicationController
  include FilterScoped
  include HasVista

  FILTER_PARAMS = [:stato, editori: [], terms: []].freeze

  before_action :authenticate_user!

  ORDINE_DEFAULT = "libri.titolo ASC".freeze

  def index
    @columns = resolve_colonne(Giacenza::Columns)
    @sort = resolve_sort(@columns)

    scope = @filter.libri.includes(:editore, :giacenza)

    @totali = totali(scope.except(:includes, :order))
    @total_count = scope.count

    # Alcuni scope (in particolare pg_search) hanno gia' un ORDER BY: va
    # sostituito, non accodato, altrimenti la scelta dell'utente e' secondaria.
    scope = @sort.active? ? apply_sort(scope, @sort) : scope.reorder(Arel.sql(ORDINE_DEFAULT))
    set_page_and_extract_portion_from scope
  end

  private

    def totali(scope)
      row = scope.pick(
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.disponibile, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.impegnato, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.campionario, 0)), 0)"),
        Arel.sql("COALESCE(SUM(GREATEST(libri.adozioni_count - (COALESCE(giacenze.disponibile, 0) - COALESCE(giacenze.impegnato, 0)), 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.venduto_copie, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.venduto_cents, 0)), 0)")
      )

      %i[disponibile impegnato campionario fabbisogno venduto_copie venduto_cents].zip(row.map(&:to_i)).to_h
    end
end
