import { Controller } from "@hotwired/stimulus"
// import mapboxgl from "mapbox-gl"
// import MapboxDirections from "@mapbox/mapbox-gl-directions"

export default class extends Controller {
  
  static targets = ["map", "totaleKm", "totaleTempo"];

  static values = {
    mapboxToken: String,
    waypoints: Array
  };

  connect() {
    this.initMap();
    document.addEventListener("refresh-map", this.refreshMap.bind(this));
  }

  refreshMap() {
    this.initMap();
  }

  initMap() {

    if (!this.mapTarget) return;

    // Rimuovi la mappa precedente se esiste (evita sovrapposizioni)
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

    // const directions = new MapboxDirections({
    //   accessToken: mapboxgl.accessToken,
    //   unit: 'metric',
    //   profile: 'mapbox/driving',
    //   interactive: false,
    //   language: 'it-IT'
    // })

    this.map.on('load', () => {

      // this.map.addControl(directions, 'top-left');

      // directions.setOrigin([coordinates[0].lng, coordinates[0].lat]);
      // directions.setDestination([coordinates[coordinates.length - 1].lng, coordinates[coordinates.length - 1].lat]);
      // this.addMarker(coordinates[0]);
      // this.addMarker(coordinates[coordinates.length - 1]);

      // coordinates.slice(1, -1).forEach((coord, index) => {
      //     directions.addWaypoint(index, [coord.lng, coord.lat]);
      //     // Aggiungi un marker sulla mappa
      //     this.addMarker(coord);
      // });

      const bounds = new mapboxgl.LngLatBounds();
      // Extend the bounds to include all waypoints
      coordinates.forEach(coord => {
          console.log(coord);
          bounds.extend(coord);
          this.addMarker(coord);
      });
      
      // Fit the map to the bounds with padding
      this.map.fitBounds(bounds, {
          padding: 100 // 50 pixels of padding
      });
    }); 

    this.fetchAndDrawRoute();
    
  }

  addMarker(coord) {
    // Aggiungiamo un controllo per debug
    console.log("Coordinate ricevute:", coord);
    
    const marker = new mapboxgl.Marker()
      .setLngLat([coord.lng, coord.lat])
      .setPopup(
        new mapboxgl.Popup({ offset: 25 }).setHTML(
          `<h3>${coord.name || "Tappa"}</h3>
           <p>${coord.description || ""}</p>
           ${coord.import_scuola_id ? 
             `<a href="/import_scuole/${coord.import_scuola_id}" class="text-blue-600 hover:text-blue-800">
                Vedi dettagli scuola
              </a>` 
             : ''
           }`
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
        const distance = data.routes[0].distance; // Distance in meters
        const duration = data.routes[0].duration; // Duration in seconds

        // Add the route to the map as a layer
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

        // Adjust map bounds to fit the route
        const bounds = new mapboxgl.LngLatBounds();
        route.coordinates.forEach((coord) => bounds.extend(coord));
        this.map.fitBounds(bounds, { padding: 50 });

        // Display the total distance
        const distanceInKm = (distance / 1000).toFixed(1); // Convert to km and round to 2 decimal places
        let durationDisplay;
        if (duration < 3600) {
          durationDisplay = `${(duration / 60).toFixed()} minuti`; // Convert to minutes and round to 2 decimal places
        } else {
          const hours = Math.floor(duration / 3600);
          const minutes = Math.round((duration % 3600) / 60);
          const hoursDisplay = hours === 1 ? `${hours} ora` : `${hours} ore`;
          const minutesDisplay = minutes === 1 ? `${minutes} minuto` : `${minutes} minuti`;
          durationDisplay = `${hoursDisplay} ${minutesDisplay}`;
        }

        console.log(`Total distance: ${distanceInKm} km`);
        console.log(`Total duration: ${durationDisplay}`);
        // You can also display this in your UI as needed
        this.totaleKmTarget.textContent = distanceInKm;
        this.totaleTempoTarget.textContent = durationDisplay;
      })
      .catch((error) => console.error("Error fetching route:", error));
  }

};

