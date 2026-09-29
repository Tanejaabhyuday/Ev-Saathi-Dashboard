import Foundation

// MARK: - AlertType

enum AlertType: String, Codable, CaseIterable {
    case speed = "speed"
    case temp  = "temp"
    case soc   = "soc"

    var displayName: String {
        switch self {
        case .speed: return "Overspeed"
        case .temp:  return "High Temp"
        case .soc:   return "Low Battery"
        }
    }

    var systemImageName: String {
        switch self {
        case .speed: return "gauge.high"
        case .temp:  return "thermometer.high"
        case .soc:   return "battery.25"
        }
    }
}

// MARK: - AlertModel

struct AlertModel: Identifiable, Codable, Hashable {
    var id: String
    var busId: String
    var type: AlertType
    var message: String
    var timestamp: Date
    var resolved: Bool

    var timeAgoString: String {
        let diff = Date().timeIntervalSince(timestamp)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        return "\(Int(diff / 3600))h ago"
    }

    func toFirestoreDict() -> [String: Any] {
        return [
            "id": id,
            "busId": busId,
            "type": type.rawValue,
            "message": message,
            "timestamp": timestamp,
            "resolved": resolved
        ]
    }

    init?(from dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let busId = dict["busId"] as? String,
            let typeRaw = dict["type"] as? String,
            let type = AlertType(rawValue: typeRaw),
            let message = dict["message"] as? String
        else { return nil }

        self.id = id
        self.busId = busId
        self.type = type
        self.message = message
        self.resolved = dict["resolved"] as? Bool ?? false

        // Firestore Timestamp → Date
        if let ts = dict["timestamp"] as? Date {
            self.timestamp = ts
        } else {
            self.timestamp = Date()
        }
    }

    init(id: String, busId: String, type: AlertType, message: String,
         timestamp: Date = Date(), resolved: Bool = false) {
        self.id = id; self.busId = busId; self.type = type
        self.message = message; self.timestamp = timestamp; self.resolved = resolved
    }
}
