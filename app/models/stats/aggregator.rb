# frozen_string_literal: true

# Calcola le aggregazioni di una Stat su un insieme di righe.
#
# Input:
#   rows           — array di hash (output di Stat#execute)
#   aggregazioni   — array prodotto da Stat#aggregazioni
#   grand_totals   — hash {col => somma_globale} per :pct_of_total (nil = 0%)
#   skip_pct_of_total — true per ometterlo nel grand total
#
# Output (Struct):
#   cells  — {nome_colonna => valore}              (aggregazioni :col)
#   extras — [{label:, value:, format:}, ...]      (aggregazioni :extra)
module Stats
  class Aggregator
    Result = Struct.new(:cells, :extras, keyword_init: true)
    Extra  = Struct.new(:label, :value, :format, keyword_init: true)

    def self.call(rows, aggregazioni, grand_totals: nil, skip_pct_of_total: false)
      new(rows, aggregazioni, grand_totals, skip_pct_of_total).call
    end

    def self.sums_by_col(rows, cols)
      cols.index_with { |c| rows.sum { |r| r[c].to_f } }
    end

    def initialize(rows, aggregazioni, grand_totals, skip_pct_of_total)
      @rows = rows
      @aggregazioni = aggregazioni
      @grand_totals = grand_totals || {}
      @skip_pct_of_total = skip_pct_of_total
    end

    def call
      Result.new(cells: compute_cells, extras: compute_extras)
    end

    private

    def compute_cells
      @aggregazioni.select { |a| a[:kind] == :col }.each_with_object({}) do |a, h|
        h[a[:col]] = compute_col(a)
      end
    end

    def compute_extras
      @aggregazioni
        .select { |a| a[:kind] == :extra }
        .reject { |a| @skip_pct_of_total && a[:op] == :pct_of_total }
        .filter_map { |a| compute_extra(a) }
    end

    def compute_col(a)
      col = a[:col]
      values = @rows.map { |r| r[col] }.compact
      case a[:op]
      when :sum   then sum_values(values)
      when :avg   then values.empty? ? 0 : values.sum(&:to_f) / values.size
      when :min   then values.min
      when :max   then values.max
      when :count then @rows.size
      end
    end

    def compute_extra(a)
      case a[:op]
      when :pct_of_total
        group_sum = @rows.sum { |r| r[a[:col]].to_f }
        total = @grand_totals[a[:col]].to_f
        value = total.zero? ? nil : (group_sum / total) * 100
        Extra.new(label: a[:label], value: value, format: :pct)
      when :pct
        sa = @rows.sum { |r| r[a[:a]].to_f }
        sb = @rows.sum { |r| r[a[:b]].to_f }
        value = sb.zero? ? nil : (sa / sb) * 100
        Extra.new(label: a[:label], value: value, format: :pct)
      when :ratio
        sa = @rows.sum { |r| r[a[:a]].to_f }
        sb = @rows.sum { |r| r[a[:b]].to_f }
        value = sb.zero? ? nil : sa / sb
        Extra.new(label: a[:label], value: value, format: :ratio)
      end
    end

    def sum_values(values)
      if values.all? { |v| v.is_a?(Integer) }
        values.sum
      else
        values.sum(&:to_f)
      end
    end
  end
end
