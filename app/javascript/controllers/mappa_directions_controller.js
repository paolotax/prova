import { Controller } from "@hotwired/stimulus"
// import mapboxgl from "mapbox-gl"
// import MapboxDirections from "@mapbox/mapbox-gl-directions"

export default class extends Controller {
  static targets = ["map"]

  connect() {
    mapboxgl.accessToken = this.data.get("mapboxAccessToken")
    const coordinates = JSON.parse(this.data.get("coordinates"))

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/streets-v11",
      center: [coordinates[0].lng, coordinates[0].lat],
      zoom: 12
    })

    const directions = new MapboxDirections({
      accessToken: mapboxgl.accessToken,
      unit: 'metric',
      profile: 'mapbox/driving'
    })

    this.map.addControl(directions, 'top-left')

    directions.setOrigin([coordinates[0].lng, coordinates[0].lat]);
    directions.setDestination([coordinates[coordinates.length - 1].lng, coordinates[coordinates.length - 1].lat]);

    coordinates.slice(1, -1).forEach((coord, index) => {
        directions.addWaypoint(index, [coord.lng, coord.lat]);
}   );

  }
}