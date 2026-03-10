import { Controller } from "@hotwired/stimulus"

const MAPBOX_JS = "https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.js"
const MAPBOX_CSS = "https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.css"

function loadMapbox() {
  if (window.mapboxgl) return Promise.resolve()

  if (!document.querySelector(`link[href="${MAPBOX_CSS}"]`)) {
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = MAPBOX_CSS
    document.head.appendChild(link)
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = MAPBOX_JS
    script.onload = resolve
    script.onerror = reject
    document.head.appendChild(script)
  })
}

export default class extends Controller {

  static targets = ["map", "totaleKm", "totaleTempo"];

  static values = {
    mapboxToken: String,
    waypoints: Array
  };

  async connect() {
    await loadMapbox()
    this.initMap();
  }

  disconnect() {
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

    mapboxgl.accessToken = this.mapboxTokenValue;
    const coordinates = JSON.parse(this.data.get("coordinates"))

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/streets-v12",
      center: [coordinates[0].lng, coordinates[0].lat],
      zoom: 12,
      language: 'it-IT'
    })

    this.map.addControl(new mapboxgl.NavigationControl(), 'top-right')

    this.map.on('load', () => {
      const bounds = new mapboxgl.LngLatBounds();
      coordinates.forEach(coord => {
        bounds.extend(coord);
        this.addMarker(coord);
      });

      this.map.fitBounds(bounds, { padding: 100 });
    });

    this.fetchAndDrawRoute();
  }

  addMarker(coord) {
    new mapboxgl.Marker()
      .setLngLat([coord.lng, coord.lat])
      .setPopup(
        new mapboxgl.Popup({ offset: 25 }).setHTML(
          `<h3>${coord.name || "Tappa"}</h3>
           <p>${coord.description || ""}</p>`
        )
      )
      .addTo(this.map);
  }

  fetchAndDrawRoute() {
    const waypoints = this.waypointsValue.map(coord => coord.join(',')).join(';');
    const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${waypoints}?geometries=geojson&access_token=${mapboxgl.accessToken}`;

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

        const bounds = new mapboxgl.LngLatBounds();
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
