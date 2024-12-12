require 'geocoder'

class PercorsoOttimale

  attr_accessor :places, :nodo_iniziale, :nodo_finale

  def initialize(places)
    @places = places
  end

  def calcola
    optimal_route = tsp_greedy(@places)

    # Stampa il percorso ottimale e aggiorna la posizione delle tappe
    puts "Percorso ottimale:"
    optimal_route.each_with_index do |place, index|

      puts place.position
      
      place.position = index + 1
      place.save

      puts "#{place.position}. #{place.denominazione} (#{place.latitude}, #{place.longitude})"
    end
  end

  private

  # Funzione per calcolare la distanza tra due coordinate
  def distance_between(lat1, lon1, lat2, lon2)
    Geocoder::Calculations.distance_between([lat1, lon1], [lat2, lon2])
  end

  # Implementazione semplice del TSP usando metodo greedy
  def tsp_greedy(places)
    start = places.first
    visited = [start]

    puts "Nodo iniziale: #{start.denominazione} (#{start.latitude}, #{start.longitude})"
    
    unvisited = places[1..-1]

    current_place = start

    while unvisited.any?
      nearest = unvisited.min_by do |place|
        distance_between(current_place.latitude, current_place.longitude, place.latitude, place.longitude)
      end

      visited << nearest
      unvisited.delete(nearest)
      current_place = nearest
    end

    visited
  end
end