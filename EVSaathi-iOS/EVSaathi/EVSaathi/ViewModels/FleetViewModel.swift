import Foundation
import Combine
import FirebaseFirestore

// MARK: - FleetViewModel
// Central view model for all fleet data.
// - Subscribes to Firestore buses, chargers, and alerts collections (real-time)
// - Runs a local 2-second simulation timer that mirrors the web app's setInterval
// - Writes updated bus positions back to Firestore so all admin devices stay in sync
// - Firestore offline persistence (enabled in FirestoreService) provides caching

final class FleetViewModel: ObservableObject {

    // MARK: Published state
    @Published var buses:    [BusModel]    = []
    @Published var chargers: [ChargerModel] = []
    @Published var alerts:   [AlertModel]  = []
    @Published var isLoaded: Bool          = false
    @Published var detailedRoutesLoaded: Bool = false

    // Firestore listener registrations (retained to keep listeners alive)
    private var busListener:     ListenerRegistration?
    private var chargerListener: ListenerRegistration?
    private var alertListener:   ListenerRegistration?

    // Simulation timer
    private var simulationTimer: Timer?
    private let refreshRate: TimeInterval = 2.0

    // Track which alert types have already been fired per bus (avoids duplicates)
    private var firedAlerts: Set<String> = []  // "busId_type"

    // MARK: - Lifecycle

    init() {
        startListening()
        startSimulation()
        
        // Fetch detailed driving paths once on startup
        RouteModel.fetchAllDetailedRoutes { [weak self] in
            self?.detailedRoutesLoaded = true
        }
    }

    deinit {
        stopListening()
        simulationTimer?.invalidate()
    }

    // MARK: - Firestore Listeners

    private func startListening() {
        busListener = FirestoreService.shared.listenToBuses { [weak self] buses in
            Task { @MainActor [weak self] in
                self?.buses = buses.sorted { $0.id < $1.id }
                self?.isLoaded = true
            }
        }
        chargerListener = FirestoreService.shared.listenToChargers { [weak self] chargers in
            Task { @MainActor [weak self] in
                self?.chargers = chargers.sorted { $0.id < $1.id }
            }
        }
        alertListener = FirestoreService.shared.listenToAlerts { [weak self] alerts in
            Task { @MainActor [weak self] in
                self?.alerts = alerts
            }
        }
    }

    private func stopListening() {
        busListener?.remove()
        chargerListener?.remove()
        alertListener?.remove()
    }

    // MARK: - Manual Refresh (Pull-to-refresh)
    func refreshData() async {
        // Stop current listeners
        stopListening()
        // Restart listeners to fetch fresh snapshot from Firestore
        startListening()
        
        // Wait a short duration to allow the UI to show the refresh spinner
        // and for the first snapshots to return from the cloud
        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    // MARK: - Static Charger Coordinates
    let chargerLocations: [String: (lat: Double, lng: Double)] = [
        "CH-1": (28.5494, 77.2522),
        "CH-2": (28.4900, 77.0886),
        "CH-3": (28.5708, 77.3216),
        "CH-4": (28.5524, 77.0583)
    ]

    // MARK: - Simulation Timer

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    /// Called every 2 seconds — mirrors the web app's setInterval logic
    private func tick() {
        guard !buses.isEmpty else { return }

        var updatedBuses: [BusModel] = []

        // Enforce at least 2 buses charging
        let chargingCount = buses.filter { $0.status == .charging || $0.status == .idle || $0.soc <= 0 }.count
        if chargingCount < 2 {
            var movingBuses = buses.enumerated().filter { $0.element.status == .moving && $0.element.soc > 0 }
            movingBuses.sort { $0.element.soc < $1.element.soc }
            for i in 0..<min(2 - chargingCount, movingBuses.count) {
                buses[movingBuses[i].offset].soc = 0
            }
        }

        for var bus in buses {
            if bus.status != .moving {
                // Charging logic
                if bus.status == .charging {
                    bus.soc = min(100, bus.soc + 0.5)
                    if bus.soc >= 95 {
                        bus.status = .moving
                        // Free the charger
                        updateChargerOccupancy(vehicleId: bus.id, occupied: false)
                        
                        // Teleport back to route
                        let route = RouteModel.find(by: bus.routeId)
                        let detailedPath = RouteModel.detailedPaths[bus.routeId]
                        let useDetailed = detailedPath != nil && !detailedPath!.isEmpty
                        let points = useDetailed ? detailedPath! : (route?.points ?? [])
                        if !points.isEmpty {
                            let targetIdx = useDetailed ? bus.pathIndex % points.count : bus.targetIndex % points.count
                            bus.latitude = points[targetIdx].lat
                            bus.longitude = points[targetIdx].lng
                        }
                    }
                } else if bus.status == .idle && bus.soc <= 0 {
                    // Bus is waiting for a charger
                    if let freeCharger = chargers.first(where: { !$0.isOccupied }) {
                        bus.status = .charging
                        updateChargerOccupancy(vehicleId: bus.id, occupied: true, chargerId: freeCharger.id)
                        if let loc = chargerLocations[freeCharger.id] {
                            bus.latitude = loc.lat
                            bus.longitude = loc.lng
                        }
                    }
                }
                
                bus.speed = 0
                updatedBuses.append(bus)
                continue
            }

            // Movement along route
            let route = RouteModel.find(by: bus.routeId)
            let detailedPath = RouteModel.detailedPaths[bus.routeId]
            let useDetailed = detailedPath != nil && !detailedPath!.isEmpty

            let points = useDetailed ? detailedPath! : (route?.points ?? [])

            if points.count > 1 {
                // If using detailed path, pathIndex is used directly
                let targetIdx = useDetailed ? bus.pathIndex % points.count : bus.targetIndex % points.count
                let target = points[targetIdx]

                let dLat = target.lat - bus.latitude
                let dLng = target.lng - bus.longitude
                let dist = sqrt(dLat * dLat + dLng * dLng)

                // Detailed paths have points very close to each other, so threshold should be smaller
                let threshold = useDetailed ? 0.0002 : 0.0005
                let speedStep = useDetailed ? 0.02 : 0.05

                if dist < threshold {
                    // Reached waypoint — advance to next
                    if useDetailed {
                        bus.pathIndex = (bus.pathIndex + 1) % points.count
                        // Jump exactly to point to prevent drift
                        bus.latitude = target.lat
                        bus.longitude = target.lng
                    } else {
                        bus.targetIndex = (bus.targetIndex + 1) % points.count
                    }
                } else {
                    bus.latitude  += (dLat / dist) * min(dist, speedStep)
                    bus.longitude += (dLng / dist) * min(dist, speedStep)
                }
            }

            // SOC drain
            bus.soc = max(0, bus.soc - 0.05)
            
            if bus.soc <= 0 {
                bus.speed = 0
                // Find a free charger and occupy it
                if let freeCharger = chargers.first(where: { !$0.isOccupied }) {
                    bus.status = .charging
                    updateChargerOccupancy(vehicleId: bus.id, occupied: true, chargerId: freeCharger.id)
                    if let loc = chargerLocations[freeCharger.id] {
                        bus.latitude = loc.lat
                        bus.longitude = loc.lng
                    }
                } else {
                    // Queue for charger
                    bus.status = .idle
                }
                updatedBuses.append(bus)
                continue
            } else {
                // Random speed variation (mirrors web: 5% chance of overspeed burst)
                let overSpeed = Double.random(in: 0...1) > 0.95
                bus.speed = overSpeed
                    ? Double.random(in: 65...85)
                    : Double.random(in: 25...55)
            }

            // Temp depends on speed
            bus.temp = 35 + (bus.speed / 10) + Double.random(in: 0...1)

            // Alert: high temperature
            let tempKey = "\(bus.id)_temp"
            if bus.temp > 45 && !firedAlerts.contains(tempKey) {
                firedAlerts.insert(tempKey)
                let alert = AlertModel(
                    id: UUID().uuidString,
                    busId: bus.id,
                    type: .temp,
                    message: "High Battery Temp: \(Int(bus.temp))°C on \(bus.id)"
                )
                FirestoreService.shared.addAlert(alert)
            }

            // Alert: overspeed
            let speedKey = "\(bus.id)_speed"
            if bus.speed > 60 && !firedAlerts.contains(speedKey) {
                firedAlerts.insert(speedKey)
                let alert = AlertModel(
                    id: UUID().uuidString,
                    busId: bus.id,
                    type: .speed,
                    message: "Overspeed: \(Int(bus.speed)) km/h on \(bus.id)"
                )
                FirestoreService.shared.addAlert(alert)
            }

            // Alert: low SOC
            let socKey = "\(bus.id)_soc"
            if bus.soc < 15 && !firedAlerts.contains(socKey) {
                firedAlerts.insert(socKey)
                let alert = AlertModel(
                    id: UUID().uuidString,
                    busId: bus.id,
                    type: .soc,
                    message: "Low Battery: \(Int(bus.soc))% on \(bus.id)"
                )
                FirestoreService.shared.addAlert(alert)
            }

            // (pathIndex is now updated strictly when reaching a waypoint to ensure accurate road tracing)
            updatedBuses.append(bus)
        }

        // Write all updated buses to Firestore in a batch
        FirestoreService.shared.setBuses(updatedBuses)
    }

    // MARK: - Charger Helpers

    private func updateChargerOccupancy(vehicleId: String, occupied: Bool, chargerId: String? = nil) {
        let idx: Int?
        if let cid = chargerId {
            idx = chargers.firstIndex(where: { $0.id == cid })
        } else {
            idx = chargers.firstIndex(where: { $0.currentVehicle == vehicleId })
        }
        guard let validIdx = idx else { return }
        var charger = chargers[validIdx]
        charger.isOccupied    = occupied
        charger.currentVehicle = occupied ? vehicleId : nil
        FirestoreService.shared.db
            .collection("chargers")
            .document(charger.id)
            .setData(charger.toFirestoreDict(), merge: true)
    }

    // MARK: - Alert Management

    func resolveAlert(id: String) {
        FirestoreService.shared.resolveAlert(id: id)
        // Also clear the fired-alert key so a new one can fire if the condition recurs
        firedAlerts = firedAlerts.filter { !$0.hasPrefix(id) }
    }

    // MARK: - Computed Properties

    var totalBuses: Int   { buses.count }
    var activeBuses: Int  { buses.filter { $0.status == .moving }.count }
    var avgSOC: Double    { buses.isEmpty ? 0 : buses.map(\.soc).reduce(0, +) / Double(buses.count) }
    var activeAlerts: Int { alerts.filter { !$0.resolved }.count }

    func alerts(for busId: String) -> [AlertModel] {
        alerts.filter { $0.busId == busId }
    }

    func bus(for id: String) -> BusModel? {
        buses.first { $0.id == id }
    }
}
