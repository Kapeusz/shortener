// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}

Hooks.GoogleMap = {
  mounted() {
    // markers passed as JSON array [{lat,lng}, ...]
    const markersJson = this.el.dataset.markers || "[]"
    let markers = []
    try { markers = JSON.parse(markersJson) } catch (_e) {}
    const apiKey = this.el.dataset.apiKey || ""

    const init = () => {
      if (!(window.google && window.google.maps)) return
      const defaultCenter = {lat: 0, lng: 0}
      const map = new google.maps.Map(this.el, {zoom: 2, center: defaultCenter})
      this.map = map
      this._bounds = new google.maps.LatLngBounds()
      this._gMarkers = []
      if (markers.length === 0) return
      markers.forEach(m => this._addMarker(m))
      if (markers.length === 1) { map.setCenter(markers[0]); map.setZoom(8) } else { map.fitBounds(this._bounds) }
    }

    const loadGoogle = (key) => new Promise((resolve, reject) => {
      if (window.google && window.google.maps) return resolve()
      if (!key) return reject(new Error("Missing Google Maps key"))
      let script = document.querySelector('script[data-gmaps]')
      if (script) { script.addEventListener('load', resolve); return }
      script = document.createElement('script')
      script.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(key)
      script.async = true; script.defer = true; script.dataset.gmaps = '1'
      script.onload = resolve; script.onerror = reject
      document.head.appendChild(script)
    })

    this.handleEvent && this.handleEvent('add-marker', (m) => {
      if (!this.map && window.google && window.google.maps) init()
      if (!this.map) return
      this._addMarker(m)
      if (this._gMarkers.length === 1) { this.map.setCenter(m); this.map.setZoom(8) }
      else { this.map.fitBounds(this._bounds) }
    })

    // helper to add a single marker and track bounds
    this._addMarker = (m) => {
      const mk = new google.maps.Marker({position: m, map: this.map})
      this._gMarkers.push(mk)
      this._bounds.extend(mk.getPosition())
    }

    loadGoogle(apiKey).then(init).catch(() => { /* key missing or load failed */ })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
