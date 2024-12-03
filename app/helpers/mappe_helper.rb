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

  def get_coordinates(scuole_ids: [], clienti_ids: [])
    #scuole_ids = current_user.tappe.di_oggi.pluck(:tappable_id)
    scuole = ImportScuola.where(id: scuole_ids)
    clienti = Cliente.where(id: clienti_ids)
    
    data = []
    
    scuole.map do |scuola|
      next if scuola.geocoded.nil? || scuola.geocoded == false 

      data << {
        latitude: scuola.latitude,
        longitude: scuola.longitude,
        label: scuola.scuola,
        color: "#85C9E6",
        tooltip: html_for_scuola(scuola),
        tipo: "ImportScuola"
      }
    
    end

    clienti.map do |cliente|
      next if cliente.geocoded.nil? || cliente.geocoded == false 

      data << {
        latitude: cliente.latitude,
        longitude: cliente.longitude,
        label: cliente.denominazione,
        color: "#f84d4d",
        tooltip: html_for_cliente(cliente),
        tipo: "Cliente"
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

end
