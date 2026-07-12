# Parse del param URL ?sort=comune.asc,denominazione.desc con whitelist
# derivata dalle colonne visibili (sortabile ciò che dichiara sort:).
# Il sort è effimero: vive nell'URL, non nei filtri salvati.
class DataTable::Sort
  DIRECTIONS = %w[ asc desc ].freeze

  attr_reader :entries

  def initialize(param, columns:)
    @columns = columns.select(&:sortable?).index_by(&:key)
    @entries = parse(param)
  end

  def active?
    entries.any?
  end

  def multi?
    entries.size > 1
  end

  # Clausole per reorder: i frammenti SQL vengono dal registro colonne
  # (definiti in codice, non dall'utente), la direzione è whitelistata.
  def order_clauses
    entries.map { |key, direction| Arel.sql("#{@columns[key].sort} #{direction.upcase} NULLS LAST") }
  end

  def direction_for(key)
    entries.assoc(key.to_sym)&.last
  end

  # Posizione 1-based nel multi-sort (per l'indicatore nell'header)
  def position_for(key)
    index = entries.index { |entry_key, _| entry_key == key.to_sym }
    index && index + 1
  end

  def to_param
    entries.map { |key, direction| "#{key}.#{direction}" }.join(",")
  end

  private
    def parse(param)
      param.to_s.split(",").filter_map { |part|
        key, direction = part.strip.split(".")
        key = key.to_s.to_sym
        next unless @columns.key?(key) && DIRECTIONS.include?(direction)
        [ key, direction ]
      }.uniq(&:first)
    end
end
