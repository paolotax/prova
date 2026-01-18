module CausaliHelper
  
  def causale_bg_class(causale)
    return "bg-gray-200" unless causale

    case causale.tipo_movimento
    when "ordine"
      causale.movimento == "entrata" ? "bg-blue-100" : "bg-indigo-100"
    when "vendita"
      causale.movimento == "entrata" ? "bg-emerald-100" : "bg-rose-100"
    when "carico"
      causale.movimento == "entrata" ? "bg-amber-100" : "bg-orange-100"
    else
      "bg-gray-200"
    end
  end

  def causale_section_bg_class(causale)
    return "bg-gray-50" unless causale

    case causale.tipo_movimento
    when "ordine"
      causale.movimento == "entrata" ? "bg-blue-50" : "bg-indigo-50"
    when "vendita"
      causale.movimento == "entrata" ? "bg-emerald-50" : "bg-rose-50"
    when "carico"
      causale.movimento == "entrata" ? "bg-amber-50" : "bg-orange-50"
    else
      "bg-gray-50"
    end
  end

  def causale_border_class(causale)
    return "border-gray-200" unless causale

    case causale.tipo_movimento
    when "ordine"
      causale.movimento == "entrata" ? "border-blue-200" : "border-indigo-200"
    when "vendita"
      causale.movimento == "entrata" ? "border-emerald-200" : "border-rose-200"
    when "carico"
      causale.movimento == "entrata" ? "border-amber-200" : "border-orange-200"
    else
      "border-gray-200"
    end
  end

  # Returns BEM modifier suffix based on causale
  # e.g., "ordine-entrata", "vendita-uscita", ""
  # Use with class_names: class_names("documento-detail__section", "documento--#{causale_bem_modifier(causale)}")
  def causale_bem_modifier(causale)
    return "" unless causale

    tipo = causale.tipo_movimento
    mov = causale.movimento

    return "" if tipo.blank? || mov.blank?

    "#{tipo}-#{mov}"
  end
end
