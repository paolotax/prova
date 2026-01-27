module ClientiHelper
  def cliente_color(cliente)
    case cliente.tipo_cliente&.downcase
    when "libreria"      then "oklch(0.6 0.15 250)"  # blue
    when "cartolibreria" then "oklch(0.6 0.15 160)"  # emerald
    when "edicola"       then "oklch(0.6 0.15 45)"   # amber
    when "cartoleria"    then "oklch(0.6 0.15 280)"  # violet
    when "grande distribuzione" then "oklch(0.6 0.15 15)" # rose
    else "oklch(0.6 0.01 0)"  # gray default
    end
  end

  def cliente_badge_class(cliente)
    return "" unless cliente.respond_to?(:documenti)
    cliente.documenti.count.positive? ? "badge--positive" : ""
  end
end
