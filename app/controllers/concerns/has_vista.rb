# Vista index card/tabella con scelta persistita in cookie per risorsa,
# più risoluzione delle colonne visibili e del sort per la vista tabella.
#
#   @vista = resolve_vista(default: "tabella")
#   @columns = resolve_colonne(Documento::Columns)
#   @sort = resolve_sort(@columns)
#   scope = apply_sort(Documento::Columns.apply_scopes(scope, @columns), @sort)
module HasVista
  extend ActiveSupport::Concern

  VISTE = %w[ card tabella ].freeze

  private
    # Il cookie viene sempre riscritto col valore risolto così che il JS di
    # back-navigation possa leggerlo e chiedere la variante giusta (row/card).
    def resolve_vista(default: "card")
      cookie_key = "#{controller_name}_vista"
      vista = params[:vista].presence_in(VISTE) ||
              cookies[cookie_key].presence_in(VISTE) ||
              default

      cookies[cookie_key] = { value: vista, expires: 1.year }
      vista
    end

    # Colonne visibili: param colonne[] (dal picker) sovrascrive e persiste
    # il cookie; colonne=default azzera. Chiavi invalide/vuote => default.
    def resolve_colonne(registry)
      cookie_key = "#{controller_name}_colonne"

      if params[:colonne].present?
        keys = Array(params[:colonne]).flat_map { |value| value.to_s.split(",") }.compact_blank.uniq

        if keys.empty? || keys == [ "default" ]
          cookies.delete(cookie_key)
          keys = []
        else
          cookies[cookie_key] = { value: keys.join(","), expires: 1.year }
        end
      else
        keys = cookies[cookie_key].to_s.split(",")
      end

      registry.visible(keys)
    end

    def resolve_sort(columns)
      DataTable::Sort.new(params[:sort], columns: columns)
    end

    def apply_sort(scope, sort)
      sort.active? ? scope.reorder(*sort.order_clauses) : scope
    end
end
