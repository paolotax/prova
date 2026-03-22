module TappeHelper

  def tappa_color(tappa)
    return "var(--color-golden)" if tappa.golden?
    return "oklch(0.6 0.01 0)" if tappa.closed?
    return "oklch(0.6 0.01 0)" if tappa.postponed?

    today = Date.current
    data = tappa.data_tappa

    return "oklch(0.6 0.15 350)"  unless data                # rosa - da programmare
    return "oklch(0.6 0.15 160)"  if data == today            # verde - oggi
    return "oklch(0.7 0.15 85)"   if data == today + 1        # gialla - domani
    return "oklch(0.6 0.15 350)"  if data > today + 1         # rosa - futura
    "oklch(0.6 0.01 0)"                                       # grigia - passata
  end

  def tappa_text_color(tappa)
    return "oklch(0.3 0.05 85)" if tappa.golden?        # scuro su dorato
    return "white" if tappa.closed?
    return "white" if tappa.postponed?

    today = Date.current
    data = tappa.data_tappa

    return "white" unless data                            # bianco su rosa
    return "white" if data == today                       # bianco su verde
    return "oklch(0.3 0.05 85)" if data == today + 1     # scuro su giallo
    return "white" if data > today + 1                    # bianco su rosa
    "white"                                               # bianco su grigio
  end

  # Returns BEM modifier class based on tappa's tappable_type
  # e.g., "tappa--import-scuola", "tappa--cliente"
  def tappa_type_modifier(tappa)
    return "" unless tappa&.tappable_type.present?

    type_slug = tappa.tappable_type.underscore.parameterize
    "tappa--#{type_slug}"
  end

  def dates_of_week(date)
    # Ensure the date is a Date object
    date = Date.parse(date.to_s) unless date.is_a?(Date)
    start_of_week = date - (date.wday - 1) % 7

    # Generate an array of dates for the week
    (0..6).map { |i| start_of_week + i }
  end


end
