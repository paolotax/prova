import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mappa-posizione"
export default class extends Controller {

  static targets = [ "map", "coordinates" ]

  connect() {

    mapboxgl.accessToken = this.data.get("mapboxAccessToken")

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: 'mapbox://styles/mapbox/satellite-streets-v12',
      center: [this.data.get("longitude"), this.data.get("latitude")],
      zoom: 16,
      pitchEnabled: true,
      zoomEnabled: true
    })

    this.map.on('load', () => {
      this.addMarkers()
    })
  }

  addMarkers() {

    const marker = new mapboxgl.Marker({
      draggable: true
    })
    .setLngLat([this.data.get("longitude"), this.data.get("latitude")])
    .addTo(this.map)

    marker.on('dragend', () => {
      const lngLat = marker.getLngLat()
      this.coordinatesTarget.style.display = 'block'
      this.coordinatesTarget.innerHTML = `Longitudine: ${lngLat.lng}<br />Latitudine: ${lngLat.lat}`
      this.updateCoordinates(this.data.get("id"), lngLat.lng, lngLat.lat);
    })
  }

  updateCoordinates(id, lng, lat) {
    fetch(`/mappe/${id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ latitude: lat, longitude: lng })
    }).then(response => response.json())
      .then(data => {
        console.log('Success:', data);
      })
      .catch((error) => {
        console.error('Error:', error);
      });
  }

  changeStyle(event) {
    const style = event.target.value
    this.map.setStyle(`mapbox://styles/mapbox/${style}`)
  }
}



