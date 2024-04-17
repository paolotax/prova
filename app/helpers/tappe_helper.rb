module TappeHelper


  def get_scuole_coordinates(scuole_ids)
    #scuole_ids = current_user.tappe.di_oggi.pluck(:tappable_id)
    scuole = ImportScuola.where(id: scuole_ids)

    data = scuole.map do |scuola|
      next if scuola.to_coordinates.empty?

      {
        latitude: scuola.to_coordinates[0],
        longitude: scuola.to_coordinates[1],
        label: scuola.scuola,
        color: "#f84d4d"
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
