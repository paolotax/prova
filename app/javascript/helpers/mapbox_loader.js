const MAPBOX_JS = "https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.js"
const MAPBOX_CSS = "https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.css"

let mapboxPromise

export function loadMapbox() {
  if (window.mapboxgl) return Promise.resolve(window.mapboxgl)
  if (mapboxPromise) return mapboxPromise

  mapboxPromise = Promise.all([
    loadStylesheet(MAPBOX_CSS),
    loadScript(MAPBOX_JS)
  ]).then(() => {
    if (!window.mapboxgl) throw new Error("Mapbox loaded without exposing mapboxgl")
    return window.mapboxgl
  }).catch((error) => {
    mapboxPromise = null
    throw error
  })

  return mapboxPromise
}

function loadScript(url) {
  const existing = document.querySelector(`script[src="${url}"]`)
  if (existing) return waitForAsset(existing)

  const script = document.createElement("script")
  script.src = url
  script.async = true
  const promise = waitForAsset(script)
  document.head.appendChild(script)
  return promise
}

function loadStylesheet(url) {
  const existing = document.querySelector(`link[rel="stylesheet"][href="${url}"]`)
  if (existing) return existing.sheet ? Promise.resolve() : waitForAsset(existing)

  const link = document.createElement("link")
  link.rel = "stylesheet"
  link.href = url
  const promise = waitForAsset(link)
  document.head.appendChild(link)
  return promise
}

function waitForAsset(element) {
  return new Promise((resolve, reject) => {
    element.addEventListener("load", resolve, { once: true })
    element.addEventListener("error", () => reject(new Error(`Failed to load ${element.src || element.href}`)), { once: true })
  })
}
