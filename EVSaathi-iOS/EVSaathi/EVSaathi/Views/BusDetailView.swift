import SwiftUI
import MapKit

// MARK: - BusDetailView
// Full detail screen for a single bus: profile, live metrics, mini map, alert log.

struct BusDetailView: View {

    let busId: String
    @EnvironmentObject private var fleetVM: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    private var bus: BusModel? { fleetVM.bus(for: busId) }
    private var route: RouteModel? { RouteModel.find(by: bus?.routeId ?? "") }
    private var busAlerts: [AlertModel] { fleetVM.alerts(for: busId) }

    var body: some View {
        Group {
            if let bus = bus {
                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: Header Card
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bus.id)
                                    .font(.system(.title2, design: .monospaced, weight: .bold))
                                Text(route?.name ?? "Unknown Route")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                StatusBadge(status: bus.status)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(18)

                        // MARK: Live Metric Tiles
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricTile(value: "\(Int(bus.speed))", unit: "km/h", icon: "gauge", color: .blue)
                            MetricTile(value: "\(Int(bus.soc))%", unit: "SOC",  icon: "battery.75", color: bus.soc < 20 ? .red : .green)
                            MetricTile(value: "\(Int(bus.temp))°", unit: "°C",  icon: "thermometer", color: .orange)
                        }

                        // MARK: Vehicle Profile
                        GroupBox {
                            VStack(spacing: 0) {
                                ProfileRow(label: "Driver",         value: bus.driverName)
                                Divider()
                                ProfileRow(label: "Distance",       value: "\(bus.distanceTraveled.formatted()) km")
                                Divider()
                                ProfileRow(label: "Battery Health", value: "\(bus.soh)%  (Good)")
                                Divider()
                                ProfileRow(label: "Last Maintenance", value: bus.lastMaintenance)
                            }
                        } label: {
                            Label("Vehicle Profile", systemImage: "person.fill")
                        }

                        // MARK: Live Map (single bus)
                        GroupBox {
                            SingleBusMapView(
                                bus: bus, 
                                route: route,
                                detailedRoutesLoaded: fleetVM.detailedRoutesLoaded
                            )
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } label: {
                            Label("Live Location", systemImage: "location.fill")
                        }

                        // MARK: Activity / Alert Log
                        GroupBox {
                            if busAlerts.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.largeTitle)
                                            .foregroundColor(.green.opacity(0.5))
                                        Text("No alerts logged for this bus.")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(busAlerts) { alert in
                                        AlertRowView(alert: alert)
                                        if alert.id != busAlerts.last?.id { Divider() }
                                    }
                                }
                            }
                        } label: {
                            Label("Activity Log  ·  \(busAlerts.count) events", systemImage: "clock.fill")
                        }

                        Spacer(minLength: 32)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(bus.id)
                .navigationBarTitleDisplayMode(.inline)

            } else {
                ProgressView("Loading bus data…")
            }
        }
    }
}

// MARK: - MetricTile

private struct MetricTile: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

// MARK: - ProfileRow

private struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

// MARK: - SingleBusMapView

private struct SingleBusMapView: UIViewRepresentable {

    let bus: BusModel
    let route: RouteModel?
    var detailedRoutesLoaded: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.register(BusAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: BusAnnotationView.reuseID)
        drawRoute(on: map)
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if detailedRoutesLoaded && !context.coordinator.hasDrawnDetailedRoutes {
            context.coordinator.hasDrawnDetailedRoutes = true
            map.removeOverlays(map.overlays)
            drawRoute(on: map)
        }

        let annotations = map.annotations.compactMap { $0 as? BusPointAnnotation }
        if let existing = annotations.first {
            UIView.animate(withDuration: 0.5) { existing.coordinate = bus.location }
            existing.bus = bus
            (map.view(for: existing) as? BusAnnotationView)?.configure(with: bus)
        } else {
            let annotation = BusPointAnnotation(bus: bus)
            map.addAnnotation(annotation)
        }
        let region = MKCoordinateRegion(center: bus.location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04))
        map.setRegion(region, animated: true)
    }

    private func drawRoute(on map: MKMapView) {
        if let route = route {
            let points = detailedRoutesLoaded 
                ? (RouteModel.detailedPaths[route.id] ?? route.points)
                : route.points
            
            let coords = points.map(\.coordinate)
            let polyline = RoutePolyline(coordinates: coords, count: coords.count)
            polyline.routeColor = route.swiftUIColor
            map.addOverlay(polyline)
        }
    }

    func makeCoordinator() -> FleetMapView.Coordinator {
        FleetMapView.Coordinator(parent: FleetMapView(
            buses: [bus], 
            chargers: [],
            routes: route.map { [$0] } ?? [],
            selectedBus: .constant(nil), region: .constant(.init()),
            detailedRoutesLoaded: detailedRoutesLoaded
        ))
    }
}
