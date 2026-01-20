module TappeHelper

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
