module MappeHelper

  def html_for_scuola(scuola)
    content_tag(:div, class: "tappable") do
      content_tag(:h4, class: "font-semibold hover:font-110%") do
        link_to(scuola.scuola, scuola)
      end +
      content_tag(:p, scuola.indirizzo) +
      content_tag(:p, "#{scuola.cap} #{scuola.comune} (#{scuola.provincia})") 
    end
  end

  def html_for_cliente(cliente)
    content_tag(:div, class: "cliente") do
      content_tag(:h4, class: "font-semibold hover:font-110%") do
        link_to(cliente.denominazione, cliente)
      end +
      content_tag(:p, cliente.indirizzo) +
      content_tag(:p, "#{cliente.cap} #{cliente.comune} (#{cliente.provincia})") 
    end
  end

  def get_coordinates(tappe)
    data = []

    tappe.each do |tappa|
      tappable = tappa.tappable
      next if tappable.geocoded.nil? || tappable.geocoded == false 

      data << {
        latitude: tappa.latitude,
        longitude: tappa.longitude,
        label: tappa.denominazione,
        color: tappable.is_a?(ImportScuola) ? "#85C9E6" : "#f84d4d",
        # tooltip: tappable.is_a?(ImportScuola) ? html_for_scuola(tappable) : html_for_cliente(tappable),
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

    data.compact
  end

  def go_to_tappable_path(tappable, provider = 'waze')
    if provider == 'waze'
      if tappable.geocoded?
        "https://waze.com/ul?ll=#{tappable.latitude},#{tappable.longitude}&navigate=yes"
      else
        "https://waze.com/ul?q=#{url_encode tappable.indirizzo_navigator}"
      end
    elsif provider == 'google'
      if tappable.geocoded?
        "https://www.google.com/maps/search/?api=1&query=#{tappable.latitude},#{tappable.longitude}"
      else
        "https://www.google.com/maps/search/?api=1&query=#{url_encode tappable.indirizzo_navigator}"
      end
    elsif provider == 'apple'
      if tappable.geocoded?
        "https://maps.apple.com/?q=#{tappable.latitude},#{tappable.longitude}"
      else
        "https://maps.apple.com/?q=#{url_encode tappable.indirizzo_navigator}"
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

  def create_apple_maps_link(coordinates)
    if coordinates.length < 2
      return "Devi fornire almeno due coordinate: partenza e destinazione."
    end
  
    origin = "#{coordinates.first[:latitude]},#{coordinates.first[:longitude]}"
    destination = "#{coordinates.last[:latitude]},#{coordinates.last[:longitude]}"
  
    link = "http://maps.apple.com/?saddr=#{origin}&daddr=#{destination}"
    
    # Nota: Apple Maps non supporta direttamente tappe intermedie nei link
    link
  end


end
