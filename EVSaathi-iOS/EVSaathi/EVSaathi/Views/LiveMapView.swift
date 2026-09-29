import SwiftUI
import MapKit

// MARK: - LiveMapView
// Full-screen MapKit map with all bus annotations and route polylines.

struct LiveMapView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel
    @State private var selectedBus: BusModel?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),  // Delhi centre
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // MARK: Full-screen Map
                FleetMapView(
                    buses: fleetVM.buses,
                    chargers: fleetVM.chargers,
                    routes: RouteModel.allRoutes,
                    selectedBus: $selectedBus,
                    region: $region,
                    detailedRoutesLoaded: fleetVM.detailedRoutesLoaded
                )
                .ignoresSafeArea(edges: .bottom)

                // MARK: Route legend overlay
                RouteLegendView()
                    .padding()
            }
            .navigationTitle("Live Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedBus) { bus in
                BusDetailView(busId: bus.id)
                    .environmentObject(fleetVM)
            }
        }
    }
}

// MARK: - FleetMapView (UIViewRepresentable)
// Uses MKMapView for full control over annotations and polylines on iOS 16+.

struct FleetMapView: UIViewRepresentable {

    let buses: [BusModel]
    let chargers: [ChargerModel]
    let routes: [RouteModel]
    @Binding var selectedBus: BusModel?
    @Binding var region: MKCoordinateRegion
    var detailedRoutesLoaded: Bool

    // Static charger coordinates (mirrors ViewModel)
    let chargerLocations: [String: CLLocationCoordinate2D] = [
        "CH-1": CLLocationCoordinate2D(latitude: 28.5494, longitude: 77.2522),
        "CH-2": CLLocationCoordinate2D(latitude: 28.4900, longitude: 77.0886),
        "CH-3": CLLocationCoordinate2D(latitude: 28.5708, longitude: 77.3216),
        "CH-4": CLLocationCoordinate2D(latitude: 28.5524, longitude: 77.0583)
    ]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.setRegion(region, animated: false)
        map.showsUserLocation = false
        map.mapType = .standard
        map.register(BusAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: BusAnnotationView.reuseID)
        // Draw initial route polylines (straight lines until detailed paths load)
        drawRoutes(on: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Redraw polylines if detailed routes just loaded
        if detailedRoutesLoaded && !context.coordinator.hasDrawnDetailedRoutes {
            context.coordinator.hasDrawnDetailedRoutes = true
            map.removeOverlays(map.overlays)
            drawRoutes(on: map)
        }

        // --- Sync Bus Annotations ---
        let existingBusAnnotations = map.annotations.compactMap { $0 as? BusPointAnnotation }
        let updatedBusIds = Set(buses.map(\.id))

        let toRemoveBuses = existingBusAnnotations.filter { !updatedBusIds.contains($0.busId) }
        map.removeAnnotations(toRemoveBuses)

        for bus in buses {
            if let existing = existingBusAnnotations.first(where: { $0.busId == bus.id }) {
                UIView.animate(withDuration: 0.4) {
                    existing.coordinate = bus.location
                }
                existing.bus = bus
                if let view = map.view(for: existing) as? BusAnnotationView {
                    view.configure(with: bus)
                }
            } else {
                let annotation = BusPointAnnotation(bus: bus)
                map.addAnnotation(annotation)
            }
        }
        
        // --- Sync Charger Annotations ---
        let existingChargerAnnotations = map.annotations.compactMap { $0 as? ChargerPointAnnotation }
        let updatedChargerIds = Set(chargers.map(\.id))
        
        let toRemoveChargers = existingChargerAnnotations.filter { !updatedChargerIds.contains($0.charger.id) }
        map.removeAnnotations(toRemoveChargers)
        
        for charger in chargers {
            guard let loc = chargerLocations[charger.id] else { continue }
            if let existing = existingChargerAnnotations.first(where: { $0.charger.id == charger.id }) {
                existing.charger = charger
                existing.subtitle = charger.isOccupied ? "Occupied by \(charger.currentVehicle ?? "Unknown")" : "Available"
                if let view = map.view(for: existing) as? MKMarkerAnnotationView {
                    view.markerTintColor = charger.isOccupied ? .systemRed : .systemGreen
                }
            } else {
                let annotation = ChargerPointAnnotation(charger: charger, coordinate: loc)
                map.addAnnotation(annotation)
            }
        }
    }

    private func drawRoutes(on map: MKMapView) {
        for route in routes {
            let points = detailedRoutesLoaded 
                ? (RouteModel.detailedPaths[route.id] ?? route.points)
                : route.points
            
            let coords = points.map(\.coordinate)
            let polyline = RoutePolyline(coordinates: coords, count: coords.count)
            polyline.routeColor = route.swiftUIColor
            map.addOverlay(polyline)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: FleetMapView
        var hasDrawnDetailedRoutes = false

        init(parent: FleetMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let busAnnotation = annotation as? BusPointAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: BusAnnotationView.reuseID,
                    for: busAnnotation
                ) as? BusAnnotationView
                view?.configure(with: busAnnotation.bus)
                return view
            }
            
            if let chargerAnnotation = annotation as? ChargerPointAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "Charger") as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: chargerAnnotation, reuseIdentifier: "Charger")
                view.glyphImage = UIImage(systemName: "bolt.car.fill")
                view.markerTintColor = chargerAnnotation.charger.isOccupied ? .systemRed : .systemGreen
                view.canShowCallout = true
                return view
            }
            
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let busAnnotation = view.annotation as? BusPointAnnotation else { return }
            DispatchQueue.main.async {
                self.parent.selectedBus = busAnnotation.bus
            }
            mapView.deselectAnnotation(view.annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(polyline.routeColor ?? .blue)
                renderer.lineWidth = 4
                renderer.alpha = 0.8
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - RoutePolyline (carries color)

class RoutePolyline: MKPolyline {
    var routeColor: Color?
}

// MARK: - ChargerPointAnnotation

class ChargerPointAnnotation: MKPointAnnotation {
    var charger: ChargerModel

    init(charger: ChargerModel, coordinate: CLLocationCoordinate2D) {
        self.charger = charger
        super.init()
        self.coordinate = coordinate
        self.title = charger.name
        self.subtitle = charger.isOccupied ? "Occupied by \(charger.currentVehicle ?? "Unknown")" : "Available"
    }
}

// MARK: - BusPointAnnotation

class BusPointAnnotation: MKPointAnnotation {
    var busId: String
    var bus: BusModel

    init(bus: BusModel) {
        self.busId = bus.id
        self.bus   = bus
        super.init()
        self.coordinate = bus.location
        self.title      = bus.id
    }
}

// MARK: - MiniFleetMapView (used on Dashboard)

struct MiniFleetMapView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel
    let buses: [BusModel]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )
    @State private var dummy: BusModel? = nil

    var body: some View {
        FleetMapView(
            buses: buses,
            chargers: fleetVM.chargers,
            routes: RouteModel.allRoutes,
            selectedBus: $dummy,
            region: $region,
            detailedRoutesLoaded: fleetVM.detailedRoutesLoaded
        )
    }
}

// MARK: - Route Legend

private struct RouteLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(RouteModel.allRoutes) { route in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(route.swiftUIColor)
                        .frame(width: 20, height: 4)
                    Text(route.name)
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
