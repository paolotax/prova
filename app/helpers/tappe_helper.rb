module TappeHelper


  def dates_of_week(date)
    # Ensure the date is a Date object
    date = Date.parse(date.to_s) unless date.is_a?(Date)
    start_of_week = date - (date.wday - 1) % 7

    # Generate an array of dates for the week
    (0..6).map { |i| start_of_week + i }
  end


end
