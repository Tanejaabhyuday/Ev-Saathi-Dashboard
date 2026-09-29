import Foundation

struct ChargerModel: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var locationName: String
    var isOccupied: Bool
    var currentVehicle: String?
    var power: Int          // kW

    var statusText: String { isOccupied ? "Occupied" : "Available" }

    func toFirestoreDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "locationName": locationName,
            "isOccupied": isOccupied,
            "power": power
        ]
        if let v = currentVehicle { dict["currentVehicle"] = v }
        return dict
    }

    init?(from dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let name = dict["name"] as? String,
            let locationName = dict["locationName"] as? String,
            let isOccupied = dict["isOccupied"] as? Bool,
            let power = dict["power"] as? Int
        else { return nil }

        self.id = id
        self.name = name
        self.locationName = locationName
        self.isOccupied = isOccupied
        self.currentVehicle = dict["currentVehicle"] as? String
        self.power = power
    }

    init(id: String, name: String, locationName: String,
         isOccupied: Bool, currentVehicle: String? = nil, power: Int) {
        self.id = id; self.name = name; self.locationName = locationName
        self.isOccupied = isOccupied; self.currentVehicle = currentVehicle; self.power = power
    }
}
