import SwiftUI
import MapKit

// MARK: - DashboardView
// Mirrors the web app's "Operations Overview" screen.

struct DashboardView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Metric Cards (2x2 grid)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCardView(
                            title: "Total Fleet",
                            value: "\(fleetVM.totalBuses)",
                            subtitle: "100% Operational",
                            icon: "bus.fill",
                            accentColor: .orange
                        )
                        MetricCardView(
                            title: "Active Buses",
                            value: "\(fleetVM.activeBuses)",
                            subtitle: "\(fleetVM.totalBuses - fleetVM.activeBuses) Idle/Charging",
                            icon: "figure.wave",
                            accentColor: .green
                        )
                        MetricCardView(
                            title: "Avg Fleet SOC",
                            value: "\(Int(fleetVM.avgSOC))%",
                            subtitle: fleetVM.avgSOC < 50 ? "Requires Attention" : "Healthy Range",
                            icon: "battery.75",
                            accentColor: fleetVM.avgSOC < 50 ? .amber : .teal
                        )
                        MetricCardView(
                            title: "Active Alerts",
                            value: "\(fleetVM.activeAlerts)",
                            subtitle: "Last 24 Hours",
                            icon: "exclamationmark.triangle.fill",
                            accentColor: .red
                        )
                    }

                    // MARK: Mini Live Map
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Live Fleet Map")
                            .font(.headline)
                            .padding(.horizontal)

                        MiniFleetMapView(buses: fleetVM.buses)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    }

                    // MARK: Recent Alerts
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent Alerts")
                                .font(.headline)
                            Spacer()
                            if !fleetVM.alerts.isEmpty {
                                Text("\(fleetVM.alerts.count) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        if fleetVM.alerts.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.green.opacity(0.5))
                                    Text("No active alerts")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 24)
                        } else {
                            ForEach(fleetVM.alerts.prefix(5)) { alert in
                                AlertRowView(alert: alert)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Operations Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        if let initials = authVM.currentUser?.initials {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Text(initials)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                AdminProfileView()
                    .environmentObject(authVM)
            }
        }
    }
}

// MARK: - Amber color (Tailwind amber-500 equivalent)

extension Color {
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let teal  = Color(red: 0.06, green: 0.72, blue: 0.51)
}
