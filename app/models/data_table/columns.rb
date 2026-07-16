# Base class per i registri colonne delle viste tabella.
#
#   class Documento::Columns < DataTable::Columns
#     self.prefix = "documenti"
#
#     column :stato, label: "Stato", width: "7.5rem"
#     column :copie, label: "Copie", width: "4rem", align: :end,
#            sort: "documenti.totale_copie"
#     # Colonna calcolata: sort e scope definiti alla bisogna
#     column :da_consegnare, label: "Da consegnare", width: "6rem", default: false,
#            sort: "COALESCE(pendenti.copie, 0)",
#            scope: ->(s) { s.left_joins_consegne_pendenti }
#   end
#
# Ogni colonna renderizza il partial "<prefix>/table/cells/_<key>".
class DataTable::Columns
  class_attribute :prefix, instance_accessor: false

  # Colonna iniziale dei checkbox (bulk actions): i registri delle liste
  # senza multi-selezione la spengono con `self.checkbox = false`.
  class_attribute :checkbox, instance_accessor: false, default: true

  class << self
    def columns
      @columns ||= []
    end

    def column(key, label:, width:, **opts)
      columns << DataTable::Column.new(key: key, label: label, width: width, partial_prefix: prefix, **opts)
    end

    def find(key)
      columns.find { |column| column.key == key.to_sym }
    end

    def defaults
      columns.select(&:default?)
    end

    # Colonne visibili date le chiavi scelte dall'utente (cookie/param),
    # nell'ordine del registro. Chiavi sconosciute ignorate; nessuna chiave
    # valida => default.
    def visible(keys)
      keys = Array(keys).map(&:to_sym)
      columns.select { |column| keys.include?(column.key) }.presence || defaults
    end

    # Applica le scope delle colonne visibili (joins/select delle calcolate)
    def apply_scopes(scope, visible_columns)
      visible_columns.reduce(scope) { |current, column| column.scope ? column.scope.call(current) : current }
    end

    # grid-template-columns: checkbox (se attiva) + colonne attive + ingranaggio
    def grid_template(visible_columns)
      tracks(visible_columns).join(" ")
    end

    # Larghezza minima della tabella per lo scroll orizzontale
    # (.data-table--scroller): somma dei minimi delle colonne (primo
    # argomento dei minmax) più checkbox, ingranaggio e gap.
    def min_inline_size(visible_columns)
      tracks = tracks(visible_columns)
      rems = tracks.sum { |track| (track[/minmax\(\s*([\d.]+)rem/, 1] || track[/([\d.]+)rem/, 1]).to_f }
      "calc(#{rems}rem + #{tracks.size - 1}ch)"
    end

    # Style inline completo per il container .data-table
    def style(visible_columns)
      "--cols: #{grid_template(visible_columns)}; --min-inline-size: #{min_inline_size(visible_columns)};"
    end

    private
      def tracks(visible_columns)
        (checkbox ? [ "2.25rem" ] : []) + visible_columns.map(&:width) + [ "2.5rem" ]
      end
  end
end
