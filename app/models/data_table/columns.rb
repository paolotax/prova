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

    # grid-template-columns: checkbox + colonne attive + ingranaggio
    def grid_template(visible_columns)
      ([ "2.25rem" ] + visible_columns.map(&:width) + [ "2.5rem" ]).join(" ")
    end
  end
end
