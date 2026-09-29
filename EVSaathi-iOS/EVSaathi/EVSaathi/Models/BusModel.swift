import Foundation
import CoreLocation

// MARK: - BusStatus

enum BusStatus: String, Codable, CaseIterable, Hashable {
    case moving   = "Moving"
    case charging = "Charging"
    case alert    = "Alert"
    case idle     = "Idle"
}

// MARK: - BusModel

struct BusModel: Identifiable, Codable, Hashable {
    var id: String           // e.g. "DL-1PC-2000"
    var routeId: String      // "R1", "R2", "R3"
    var status: BusStatus
    var latitude: Double
    var longitude: Double
    var soc: Double          // State of Charge (%)
    var temp: Double         // Battery temperature (°C)
    var speed: Double        // km/h
    var driverName: String
    var distanceTraveled: Int
    var soh: Int             // State of Health (%)
    var lastMaintenance: String
    var pathIndex: Int       // Current index along detailed route path (simulation)
    var targetIndex: Int     // Current target waypoint index (simulation fallback)

    // Computed – not stored in Firestore
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: BusModel, rhs: BusModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Convert to a plain [String: Any] dictionary for Firestore writes
    func toFirestoreDict() -> [String: Any] {
        return [
            "id": id,
            "routeId": routeId,
            "status": status.rawValue,
            "latitude": latitude,
            "longitude": longitude,
            "soc": soc,
            "temp": temp,
            "speed": speed,
            "driverName": driverName,
            "distanceTraveled": distanceTraveled,
            "soh": soh,
            "lastMaintenance": lastMaintenance,
            "pathIndex": pathIndex,
            "targetIndex": targetIndex
        ]
    }

    // Initialise from a Firestore document dictionary
    init?(from dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let routeId = dict["routeId"] as? String,
            let statusRaw = dict["status"] as? String,
            let status = BusStatus(rawValue: statusRaw),
            let latitude = dict["latitude"] as? Double,
            let longitude = dict["longitude"] as? Double,
            let soc = dict["soc"] as? Double,
            let temp = dict["temp"] as? Double,
            let speed = dict["speed"] as? Double,
            let driverName = dict["driverName"] as? String,
            let distanceTraveled = dict["distanceTraveled"] as? Int,
            let soh = dict["soh"] as? Int,
            let lastMaintenance = dict["lastMaintenance"] as? String
        else { return nil }

        self.id = id
        self.routeId = routeId
        self.status = status
        self.latitude = latitude
        self.longitude = longitude
        self.soc = soc
        self.temp = temp
        self.speed = speed
        self.driverName = driverName
        self.distanceTraveled = distanceTraveled
        self.soh = soh
        self.lastMaintenance = lastMaintenance
        self.pathIndex = dict["pathIndex"] as? Int ?? 0
        self.targetIndex = dict["targetIndex"] as? Int ?? 1
    }

    // Memberwise init (used for seed / in-memory creation)
    init(id: String, routeId: String, status: BusStatus, latitude: Double, longitude: Double,
         soc: Double, temp: Double, speed: Double, driverName: String, distanceTraveled: Int,
         soh: Int, lastMaintenance: String, pathIndex: Int = 0, targetIndex: Int = 1) {
        self.id = id; self.routeId = routeId; self.status = status
        self.latitude = latitude; self.longitude = longitude
        self.soc = soc; self.temp = temp; self.speed = speed
        self.driverName = driverName; self.distanceTraveled = distanceTraveled
        self.soh = soh; self.lastMaintenance = lastMaintenance
        self.pathIndex = pathIndex; self.targetIndex = targetIndex
    }
}
