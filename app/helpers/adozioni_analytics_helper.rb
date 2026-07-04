module AdozioniAnalyticsHelper
  # Sezioni pesate: intere quasi sempre, mezze quando ci sono fascicoli AMBITO.
  def sezioni_fmt(value)
    value = value.to_f
    (value % 1).zero? ? value.to_i.to_s : number_with_precision(value, precision: 1)
  end

  def anno_scolastico_label(anno)
    return if anno.blank?

    "#{anno[0, 4]}/#{anno[4, 2]}"
  end
end
