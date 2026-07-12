# Value object per una colonna di tabella (vista tabella delle index).
# Le colonne si definiscono nei registri per risorsa (es. Documento::Columns).
class DataTable::Column
  attr_reader :key, :label, :width, :align, :partial, :sort, :scope

  def initialize(key:, label:, width:, partial_prefix:, align: :start, partial: nil,
                 sort: nil, scope: nil, default: true, hide_mobile: false)
    @key = key.to_sym
    @label = label
    @width = width
    @align = align
    @partial = partial || "#{partial_prefix}/table/cells/#{key}"
    @sort = sort
    @scope = scope
    @default = default
    @hide_mobile = hide_mobile
  end

  def sortable?
    sort.present?
  end

  def default?
    @default
  end

  def hide_mobile?
    @hide_mobile
  end
end
