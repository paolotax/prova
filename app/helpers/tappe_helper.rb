module TappeHelper

  def html_for_scuola(scuola)
    content_tag(:div, class: "scuola") do
      content_tag(:h4, class: "font-semibold hover:font-110%") do
        link_to(scuola.scuola, scuola)
      end +
      content_tag(:p, scuola.indirizzo) +
      content_tag(:p, "#{scuola.cap} #{scuola.comune} (#{scuola.provincia})")
    end
  end

  def get_scuole_coordinates(scuole_ids)
    #scuole_ids = current_user.tappe.di_oggi.pluck(:tappable_id)
    scuole = ImportScuola.where(id: scuole_ids)

    data = scuole.map do |scuola|
      next if scuola.geocoded.nil? || scuola.geocoded == false 

      {
        latitude: scuola.latitude,
        longitude: scuola.longitude,
        label: scuola.scuola,
        color: "#f84d4d",
        tooltip: html_for_scuola(scuola)
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

end
