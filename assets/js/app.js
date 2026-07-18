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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/smart_city_lamp"
import topbar from "../vendor/topbar"
import L from "leaflet"
import "leaflet-routing-machine"

const DeviceMap = {
  mounted() {
    this.map = L.map(this.el, {zoomControl: false, attributionControl: true}).setView([-6.2146, 106.825], 13)
    L.control.zoom({position: "bottomright"}).addTo(this.map)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 20,
    }).addTo(this.map)
    this.markers = L.layerGroup().addTo(this.map)
    this.renderMarkers()
    this.handleEvent("devices_updated", ({devices}) => this.renderMarkers(devices))
    this.handleEvent("repair_route_started", dispatch => this.startTechnicianRoute(dispatch))
    this.handleEvent("repair_status_updated", dispatch => this.updateRepairStatus(dispatch))
    this.handleEvent("repair_completed", dispatch => this.completeTechnicianRoute(dispatch))
    this.handleEvent("technician_returning", dispatch => this.startTechnicianRoute(dispatch))
    this.handleEvent("technician_returned", dispatch => this.completeTechnicianRoute(dispatch))
    if (this.el.dataset.repair) {
      const repair = JSON.parse(this.el.dataset.repair)
      if (repair.status !== "queued") this.startTechnicianRoute(repair)
    }
  },
  updated() {
    this.renderMarkers()
  },
  renderMarkers(devices = null) {
    this.markers.clearLayers()
    devices = devices || JSON.parse(this.el.dataset.devices || "[]")
    devices.forEach(device => {
      const status = device.status
      const marker = L.marker([device.latitude, device.longitude], {
        icon: L.divIcon({
          className: "lamp-map-marker-wrap",
          html: `<span class="device-map-marker ${status}"><span></span></span>`,
          iconSize: [34, 34],
          iconAnchor: [17, 17],
        }),
      })
      marker.bindPopup(`<div class="device-popup"><small>${device.device_code}</small><strong>${device.name}</strong><span>${device.address}</span><b>${device.connectivity_status} · ${status}</b></div>`)
      if (this.el.dataset.selectable === "true") {
        marker.on("click", () => this.pushEvent("select_device", {id: device.id}))
      }
      marker.addTo(this.markers)
    })
  },
  startTechnicianRoute(dispatch) {
    this.clearTechnicianRoute()
    const routeToken = `${dispatch.id}-${dispatch.status}-${Date.now()}`
    this.activeRouteToken = routeToken
    const originData = dispatch.origin || dispatch.office
    const office = L.latLng(originData.latitude, originData.longitude)
    const destination = L.latLng(dispatch.destination.latitude, dispatch.destination.longitude)

    this.officeMarker = L.marker(office, {
      icon: L.divIcon({
        className: "technician-office-marker",
        html: '<span title="Technician office">TECH</span>',
        iconSize: [42, 24],
        iconAnchor: [21, 12],
      }),
    }).addTo(this.map).bindTooltip(originData.name)

    this.routingControl = L.Routing.control({
      waypoints: [office, destination],
      router: L.Routing.osrmv1({serviceUrl: "https://router.project-osrm.org/route/v1"}),
      addWaypoints: false,
      draggableWaypoints: false,
      routeWhileDragging: false,
      fitSelectedRoutes: true,
      show: false,
      createMarker: () => null,
      lineOptions: {styles: [{color: "#ffffff", opacity: 0.9, weight: 8}, {color: "#0f766e", opacity: 0.9, weight: 4}]},
    }).on("routesfound", event => {
      if (this.activeRouteToken !== routeToken) return
      const coordinates = event.routes[0].coordinates
      const elapsed = dispatch.en_route_at ? Math.max(Date.now() - Date.parse(dispatch.en_route_at), 0) : 0
      this.animateTechnician(coordinates, dispatch.travel_ms, elapsed, routeToken)
    }).addTo(this.map)
  },
  animateTechnician(coordinates, duration, elapsed = 0, routeToken = this.activeRouteToken) {
    if (!coordinates.length) return
    const icon = L.icon({
      iconUrl: "/assets/svg/technician-svgrepo-com.svg",
      iconSize: [42, 42],
      iconAnchor: [21, 36],
      className: "technician-route-icon",
    })
    this.technicianMarker = L.marker(coordinates[0], {icon, zIndexOffset: 1200}).addTo(this.map)
    this.technicianMarker.bindTooltip("Technician en route", {direction: "top"})

    const distances = [0]
    for (let i = 1; i < coordinates.length; i++) {
      distances.push(distances[i - 1] + this.map.distance(coordinates[i - 1], coordinates[i]))
    }
    const total = distances[distances.length - 1] || 1
    const startedAt = performance.now() - Math.min(elapsed, duration)

    const frame = now => {
      if (this.activeRouteToken !== routeToken) return
      const progress = Math.min((now - startedAt) / duration, 1)
      const targetDistance = total * progress
      let index = distances.findIndex(distance => distance >= targetDistance)
      if (index < 1) index = Math.min(1, coordinates.length - 1)
      const before = distances[index - 1] || 0
      const segment = (distances[index] || total) - before || 1
      const ratio = (targetDistance - before) / segment
      const from = coordinates[index - 1] || coordinates[0]
      const to = coordinates[index]
      this.technicianMarker.setLatLng([from.lat + (to.lat - from.lat) * ratio, from.lng + (to.lng - from.lng) * ratio])
      if (progress < 1) this.technicianAnimation = requestAnimationFrame(frame)
    }
    this.technicianAnimation = requestAnimationFrame(frame)
  },
  updateRepairStatus(dispatch) {
    if (dispatch.status === "en_route") {
      this.startTechnicianRoute(dispatch)
      return
    }
    if (this.technicianMarker && dispatch.status === "repairing") {
      this.technicianMarker.setLatLng([dispatch.destination.latitude, dispatch.destination.longitude])
      this.technicianMarker.setTooltipContent(`Technician repairing · ${Math.round(dispatch.repair_ms / 1000)}s`)
      this.technicianMarker.openTooltip()
    }
  },
  completeTechnicianRoute(dispatch) {
    if (this.technicianMarker) {
      this.technicianMarker.setTooltipContent("Repair completed")
      this.technicianMarker.openTooltip()
    }
    const completedRouteToken = this.activeRouteToken
    this.routeCleanupTimer = window.setTimeout(() => {
      if (this.activeRouteToken === completedRouteToken) this.clearTechnicianRoute()
    }, 2500)
  },
  clearTechnicianRoute() {
    if (this.routeCleanupTimer) window.clearTimeout(this.routeCleanupTimer)
    if (this.technicianAnimation) cancelAnimationFrame(this.technicianAnimation)
    if (this.routingControl) this.map.removeControl(this.routingControl)
    if (this.technicianMarker) this.map.removeLayer(this.technicianMarker)
    if (this.officeMarker) this.map.removeLayer(this.officeMarker)
    this.technicianAnimation = null
    this.routeCleanupTimer = null
    this.activeRouteToken = null
    this.routingControl = null
    this.technicianMarker = null
    this.officeMarker = null
  },
  destroyed() {
    this.clearTechnicianRoute()
    this.map.remove()
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, DeviceMap},
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

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
