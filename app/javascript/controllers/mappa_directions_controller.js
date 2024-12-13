import { Controller } from "@hotwired/stimulus"
// import mapboxgl from "mapbox-gl"
// import MapboxDirections from "@mapbox/mapbox-gl-directions"

export default class extends Controller {
  static targets = ["map"]

  connect() {
    this.initMap();
  }

  initMap() {

    if (!this.mapTarget) return;

    // Rimuovi la mappa precedente se esiste (evita sovrapposizioni)
    if (this.map) {
      this.map.remove();
    }

    mapboxgl.accessToken = this.data.get("mapboxAccessToken")
    const coordinates = JSON.parse(this.data.get("coordinates"))

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/streets-v11",
      center: [coordinates[0].lng, coordinates[0].lat],
      zoom: 12,
      language: 'it-IT'
    })

    const directions = new MapboxDirections({
      accessToken: mapboxgl.accessToken,
      unit: 'metric',
      profile: 'mapbox/driving',
      interactive: false,
      language: 'it-IT'
    })

    this.map.on('load', () => {

      this.map.addControl(directions, 'top-left');

      directions.setOrigin([coordinates[0].lng, coordinates[0].lat]);
      directions.setDestination([coordinates[coordinates.length - 1].lng, coordinates[coordinates.length - 1].lat]);
      this.addMarker(coordinates[0]);
      this.addMarker(coordinates[coordinates.length - 1]);

      coordinates.slice(1, -1).forEach((coord, index) => {
          directions.addWaypoint(index, [coord.lng, coord.lat]);
          // Aggiungi un marker sulla mappa
          this.addMarker(coord);
      });

      const bounds = new mapboxgl.LngLatBounds();
      // Extend the bounds to include all waypoints
      coordinates.forEach(coord => {
          console.log(coord);
          bounds.extend(coord);
      });
      
      // Fit the map to the bounds with padding
      this.map.fitBounds(bounds, {
          padding: 50 // 50 pixels of padding
      });
    }); 
    

    // Force geometry rendering
    directions.on("route", (e) => {
      if (e.route && e.route.length > 0) {
        console.log("Route geometry updated successfully.");
      } else {
        console.warn("No route found.");
      }
    });

    this.forceGeometryRender(directions);
  }

  forceGeometryRender(directions) {
    // Trigger a manual render if waypoints are set
    directions.on("waypoint", () => {
      console.log("Waypoint set. Updating route...");
      directions.queryRenderedFeatures();
    });
  }

  addMarker(coord) {
    const marker = new mapboxgl.Marker()
      .setLngLat([coord.lng, coord.lat])
      .setPopup(
        new mapboxgl.Popup({ offset: 25 }).setHTML(
          `<h3>${coord.name || "Tappa"}</h3><p>${coord.description || ""}</p>`
        )
      ) // Aggiungi un popup con il nome e la descrizione
      .addTo(this.map);
  }

}

