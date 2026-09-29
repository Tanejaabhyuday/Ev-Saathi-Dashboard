import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Waypoint

struct Waypoint: Codable, Hashable {
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - RouteModel

struct RouteModel: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var points: [Waypoint]

    var swiftUIColor: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Static Delhi Routes (mirrors web app)

extension RouteModel {
    static let allRoutes: [RouteModel] = [
        RouteModel(
            id: "R1",
            name: "Connaught Place Circle",
            colorHex: "#3B82F6",
            points: [
                Waypoint(lat: 28.6315, lng: 77.2167),
                Waypoint(lat: 28.6327, lng: 77.2197),
                Waypoint(lat: 28.6295, lng: 77.2215),
                Waypoint(lat: 28.6280, lng: 77.2180),
                Waypoint(lat: 28.6315, lng: 77.2167)
            ]
        ),
        RouteModel(
            id: "R2",
            name: "IGI Airport Express",
            colorHex: "#10B981",
            points: [
                Waypoint(lat: 28.6139, lng: 77.2090),
                Waypoint(lat: 28.5900, lng: 77.1600),
                Waypoint(lat: 28.5562, lng: 77.1000)
            ]
        ),
        RouteModel(
            id: "R3",
            name: "Noida-Gurgaon Link",
            colorHex: "#F59E0B",
            points: [
                Waypoint(lat: 28.5355, lng: 77.3910),
                Waypoint(lat: 28.5300, lng: 77.2700),
                Waypoint(lat: 28.4595, lng: 77.0266)
            ]
        )
    ]

    // Cache for real road navigation paths (snapped to roads via MKDirections)
    static var detailedPaths: [String: [Waypoint]] = [:]

    static func find(by id: String) -> RouteModel? {
        allRoutes.first { $0.id == id }
    }

    /// Fetches real road paths for all routes asynchronously using MapKit Directions
    static func fetchAllDetailedRoutes(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for route in allRoutes {
            guard route.points.count >= 2 else { continue }
            var segments: [[Waypoint]] = []
            var segmentsLoaded = 0
            let totalSegments = route.points.count - 1

            for i in 0..<totalSegments {
                segments.append([]) // placeholder
                group.enter()
                let req = MKDirections.Request()
                req.source = MKMapItem(placemark: MKPlacemark(coordinate: route.points[i].coordinate))
                req.destination = MKMapItem(placemark: MKPlacemark(coordinate: route.points[i+1].coordinate))
                req.transportType = .automobile

                MKDirections(request: req).calculate { resp, error in
                    if let route = resp?.routes.first {
                        let pointCount = route.polyline.pointCount
                        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                        segments[i] = coords.map { Waypoint(lat: $0.latitude, lng: $0.longitude) }
                    }
                    segmentsLoaded += 1
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                // Stitch segments together
                let flatPath = segments.flatMap { $0 }
                if !flatPath.isEmpty {
                    Self.detailedPaths[route.id] = flatPath
                }
                if Self.detailedPaths.count == allRoutes.count {
                    completion()
                }
            }
        }
    }
}

// MARK: - Color(hex:) extension

extension Color {
    init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexStr = hexStr.hasPrefix("#") ? String(hexStr.dropFirst()) : hexStr
        guard hexStr.count == 6,
              let value = UInt64(hexStr, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value          & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
