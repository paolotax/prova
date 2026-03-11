class PercorsoOttimale
  RAD = Math::PI / 180

  def initialize(tappe, start_id: nil, end_id: nil)
    @tappe = tappe.to_a
    @start_id = start_id
    @end_id = end_id
  end

  def calcola
    geocoded = @tappe.select { |t| t.latitude.present? && t.longitude.present? }
    return if geocoded.size < 2

    # Separa start e end fissi
    start_tappa = @start_id.present? ? geocoded.find { |t| t.id.to_s == @start_id.to_s } : nil
    end_tappa = @end_id.present? ? geocoded.find { |t| t.id.to_s == @end_id.to_s } : nil

    # Rimuovi start e end dal pool da ottimizzare
    middle = geocoded.dup
    middle.delete(start_tappa) if start_tappa
    middle.delete(end_tappa) if end_tappa

    # Ottimizza il percorso intermedio
    if start_tappa && middle.any?
      ordered_middle = tsp_greedy(middle, from: start_tappa)
    elsif middle.any?
      ordered_middle = tsp_greedy(middle)
    else
      ordered_middle = []
    end

    # Assembla il percorso finale
    ordered = []
    ordered << start_tappa if start_tappa
    ordered.concat(ordered_middle)
    ordered << end_tappa if end_tappa

    # Aggiorna le posizioni (usa valori negativi temporanei per evitare conflitti sul vincolo unique)
    Tappa.transaction do
      all_ids = @tappe.map(&:id)
      Tappa.where(id: all_ids).update_all("position = -position - 1000")

      # Tappe non geocoded vanno in fondo
      non_geocoded = @tappe - geocoded
      final_order = ordered + non_geocoded

      final_order.each_with_index do |tappa, index|
        tappa.update_columns(position: index + 1)
      end
    end
  end

  private

  def distance(lat1, lon1, lat2, lon2)
    dlat = (lat2 - lat1) * RAD
    dlon = (lon2 - lon1) * RAD
    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * RAD) * Math.cos(lat2 * RAD) * Math.sin(dlon / 2)**2
    2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  def tsp_greedy(places, from: nil)
    current = from || places.first
    unvisited = from ? places.dup : places[1..]
    visited = from ? [] : [places.first]

    while unvisited.any?
      nearest = unvisited.min_by { |p| distance(current.latitude, current.longitude, p.latitude, p.longitude) }
      visited << nearest
      unvisited.delete(nearest)
      current = nearest
    end

    visited
  end
end
