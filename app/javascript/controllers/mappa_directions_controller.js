import { Controller } from "@hotwired/stimulus"
import { loadMapbox } from "helpers/mapbox_loader"

export default class extends Controller {

  static targets = ["map", "totaleKm", "totaleTempo"];

  static values = {
    mapboxToken: String,
    waypoints: Array
  };

  async connect() {
    this.connected = true

    try {
      await loadMapbox()
    } catch (error) {
      console.error("Unable to load Mapbox", error)
      return
    }
    if (!this.connected) return

    this.initMap();
  }

  disconnect() {
    this.connected = false
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initMap() {
    if (!this.mapTarget) return;

    if (this.map) {
      this.map.remove();
    }

    window.mapboxgl.accessToken = this.mapboxTokenValue;
    const coordinates = JSON.parse(this.data.get("coordinates"))

    this.map = new window.mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/streets-v12",
      center: [coordinates[0].lng, coordinates[0].lat],
      zoom: 12,
      language: 'it-IT'
    })

    this.map.addControl(new window.mapboxgl.NavigationControl(), 'top-right')

    this.map.on('load', () => {
      const bounds = new window.mapboxgl.LngLatBounds();
      coordinates.forEach(coord => {
        bounds.extend(coord);
        this.addMarker(coord);
      });

      this.map.fitBounds(bounds, { padding: 100 });
      this.fetchAndDrawRoute();
    });
  }

  addMarker(coord) {
    new window.mapboxgl.Marker()
      .setLngLat([coord.lng, coord.lat])
      .setPopup(
        new window.mapboxgl.Popup({ offset: 25 }).setHTML(
          `<h3>${coord.name || "Tappa"}</h3>
           <p>${coord.description || ""}</p>`
        )
      )
      .addTo(this.map);
  }

  fetchAndDrawRoute() {
    const waypoints = this.waypointsValue.map(coord => coord.join(',')).join(';');
    const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${waypoints}?geometries=geojson&access_token=${window.mapboxgl.accessToken}`;

    fetch(url)
      .then((response) => response.json())
      .then((data) => {
        const route = data.routes[0].geometry;
        const distance = data.routes[0].distance;
        const duration = data.routes[0].duration;

        this.map.addLayer({
          id: "route",
          type: "line",
          source: {
            type: "geojson",
            data: {
              type: "Feature",
              properties: {},
              geometry: route
            }
          },
          layout: {
            "line-join": "round",
            "line-cap": "round"
          },
          paint: {
            "line-color": "#3887be",
            "line-width": 6,
            "line-opacity": 0.75
          }
        });

        const bounds = new window.mapboxgl.LngLatBounds();
        route.coordinates.forEach((coord) => bounds.extend(coord));
        this.map.fitBounds(bounds, { padding: 50 });

        const distanceInKm = (distance / 1000).toFixed(1);
        let durationDisplay;
        if (duration < 3600) {
          durationDisplay = `${(duration / 60).toFixed()} minuti`;
        } else {
          const hours = Math.floor(duration / 3600);
          const minutes = Math.round((duration % 3600) / 60);
          const hoursDisplay = hours === 1 ? `${hours} ora` : `${hours} ore`;
          const minutesDisplay = minutes === 1 ? `${minutes} minuto` : `${minutes} minuti`;
          durationDisplay = `${hoursDisplay} ${minutesDisplay}`;
        }

        if (this.hasTotaleKmTarget) this.totaleKmTarget.textContent = distanceInKm;
        if (this.hasTotaleTempoTarget) this.totaleTempoTarget.textContent = durationDisplay;
      })
      .catch((error) => console.error("Error fetching route:", error));
  }
}
