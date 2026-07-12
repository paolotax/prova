import { Controller } from "@hotwired/stimulus"
import { loadMapbox } from "helpers/mapbox_loader"

// Connects to data-controller="mappa-posizione"
export default class extends Controller {

  static targets = [ "map", "coordinates" ]
  static values = { updateUrl: String, denominazione: String, indirizzo: String }

  async connect() {
    this.connected = true

    try {
      await loadMapbox()
    } catch (error) {
      console.error("Unable to load Mapbox", error)
      return
    }
    if (!this.connected) return

    window.mapboxgl.accessToken = this.data.get("mapboxAccessToken")

    this.map = new window.mapboxgl.Map({
      container: this.mapTarget,
      style: 'mapbox://styles/mapbox/satellite-streets-v12',
      center: [this.data.get("longitude"), this.data.get("latitude")],
      zoom: 16,
      pitchEnabled: true,
      zoomEnabled: true
    })

    this.map.addControl(new window.mapboxgl.NavigationControl({ visualizePitch: true }), 'top-right')

    this.map.on('load', () => {
      this.addMarkers()
    })
  }

  disconnect() {
    this.connected = false
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  addMarkers() {
    const lng = this.data.get("longitude")
    const lat = this.data.get("latitude")

    this.popup = new window.mapboxgl.Popup({ offset: 25, closeButton: false, closeOnClick: false })
      .setHTML(this.#coordsHtml(lat, lng))

    const marker = new window.mapboxgl.Marker({ draggable: true })
      .setLngLat([lng, lat])
      .setPopup(this.popup)
      .addTo(this.map)

    this.popup.addTo(this.map)

    marker.on('dragend', () => {
      const lngLat = marker.getLngLat()
      this.popup.setHTML(this.#coordsHtml(lngLat.lat, lngLat.lng))
      this.coordinatesTarget.style.display = 'block'
      this.coordinatesTarget.innerHTML = `Longitudine: ${lngLat.lng}<br />Latitudine: ${lngLat.lat}`
      this.updateCoordinates(this.data.get("id"), lngLat.lng, lngLat.lat);
    })
  }

  #coordsHtml(lat, lng) {
    const nome = this.hasDenominazioneValue ? `<strong style="font-size:12px">${this.denominazioneValue}</strong><br>` : ''
    const addr = this.hasIndirizzoValue && this.indirizzoValue ? `<span style="font-size:11px;color:#666">${this.indirizzoValue}</span><br>` : ''
    return `${nome}${addr}<span style="font-size:10px;font-family:monospace;color:#999">${Number(lat).toFixed(6)}, ${Number(lng).toFixed(6)}</span>`
  }

  updateCoordinates(id, lng, lat) {
    const url = this.hasUpdateUrlValue ? this.updateUrlValue : `/mappe/${id}`
    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ latitude: lat, longitude: lng })
    }).then(response => response.json())
      .then(data => {
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
