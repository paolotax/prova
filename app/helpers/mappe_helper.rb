module MappeHelper

  def html_for_tappable(tappable)
    content_tag(:div) do
      content_tag(:h4, class: "font-semibold") do
        link_to(tappable.denominazione, tappable)
      end +
      content_tag(:p, tappable.indirizzo) +
      content_tag(:p, "#{tappable.cap} #{tappable.comune} (#{tappable.provincia})")
    end
  end

  def get_coordinates(tappe)
    data = tappe.filter_map do |tappa|
      tappable = tappa.tappable
      next unless tappable&.geocoded?

      {
        latitude: tappa.latitude,
        longitude: tappa.longitude,
        label: tappa.denominazione,
        color: tappable.is_a?(Scuola) ? "#85C9E6" : "#f84d4d",
        tooltip: html_for_tappable(tappable),
        tipo: tappable.class.name
      }
    end

    if data.empty?
      data = [{
        latitude: 44.703407,
        longitude: 10.65732,
        label: "Didattitax",
        color: "#f84d4d"
      }]
    end

    data
  end

  def go_to_tappable_path(tappable, provider = 'waze')
    if provider == 'waze'
      if tappable.geocoded?
        "https://waze.com/ul?ll=#{tappable.latitude},#{tappable.longitude}&navigate=yes"
      else
        "https://waze.com/ul?q=#{url_encode tappable.indirizzo_navigator}"
      end
    elsif provider.in?(['google', 'google_maps'])
      if tappable.geocoded?
        "https://www.google.com/maps/dir/?api=1&destination=#{tappable.latitude},#{tappable.longitude}&travelmode=driving"
      else
        "https://www.google.com/maps/dir/?api=1&destination=#{url_encode tappable.indirizzo_navigator}&travelmode=driving"
      end
    elsif provider.in?(['apple', 'apple_maps'])
      if tappable.geocoded?
        "https://maps.apple.com/?daddr=#{tappable.latitude},#{tappable.longitude}&dirflg=d"
      else
        "https://maps.apple.com/?daddr=#{url_encode tappable.indirizzo_navigator}&dirflg=d"
      end
    end
  end

  def waze_url(coordinates)

    #raise coordinates.inspect
    base_url = "https://waze.com/ul"
    params = coordinates.map.with_index do |coord, index|
      if index == 0
        "ll=#{coord[:latitude]},#{coord[:longitude]}"
      else
        "via=#{coord[:latitude]},#{coord[:longitude]}"
      end
    end
    "#{base_url}?#{params.join('&')}&navigate=yes"
  end

  def create_google_maps_link(coordinates)
    
    if coordinates.length < 2
      return "Devi fornire almeno due coordinate: partenza e destinazione."
    end
  
    origin = "#{coordinates.first[:latitude]},#{coordinates.first[:longitude]}"
    destination = "#{coordinates.last[:latitude]},#{coordinates.last[:longitude]}"
    waypoints = coordinates[1...-1].map { |coord| "#{coord[:latitude]},#{coord[:longitude]}" }.join('|')
  
    link = "https://www.google.com/maps/dir/?api=1&origin=#{origin}&destination=#{destination}"
    link += "&waypoints=#{waypoints}" unless waypoints.empty?
  
    link
  end


end
