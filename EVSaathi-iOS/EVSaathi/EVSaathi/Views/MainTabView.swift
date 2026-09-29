import SwiftUI

// MARK: - MainTabView
// Five-tab navigation matching the web app's sidebar.

struct MainTabView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var fleetVM = FleetViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            LiveMapView()
                .tabItem { Label("Live Map", systemImage: "map.fill") }
                .tag(1)

            FleetStatusView()
                .tabItem { Label("Fleet", systemImage: "bus.fill") }
                .tag(2)

            ChargingView()
                .tabItem { Label("Charging", systemImage: "bolt.fill") }
                .tag(3)

            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: fleetVM.activeAlerts > 0 ? "exclamationmark.triangle.fill"
                                                                           : "exclamationmark.triangle")
                }
                .tag(4)
                .badge(fleetVM.activeAlerts > 0 ? fleetVM.activeAlerts : 0)
        }
        .tint(.orange)
        .environmentObject(fleetVM)
        .environmentObject(authVM)
    }
}
