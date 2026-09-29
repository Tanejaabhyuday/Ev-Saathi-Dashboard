import SwiftUI

// MARK: - AlertsView
// Full alert feed with type filter and swipe-to-resolve.

struct AlertsView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel
    @State private var filterType: AlertType? = nil
    @State private var showResolvedOnly: Bool  = false

    private var filteredAlerts: [AlertModel] {
        fleetVM.alerts.filter { alert in
            let typeMatch = filterType == nil || alert.type == filterType
            let resolvedMatch = showResolvedOnly ? alert.resolved : true
            return typeMatch && resolvedMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(label: "All", isSelected: filterType == nil) {
                            filterType = nil
                        }
                        ForEach(AlertType.allCases, id: \.self) { type in
                            FilterChip(
                                label: type.displayName,
                                isSelected: filterType == type,
                                color: alertColor(type)
                            ) {
                                filterType = filterType == type ? nil : type
                            }
                        }
                        Divider().frame(height: 20)
                        Toggle("Resolved", isOn: $showResolvedOnly)
                            .font(.subheadline)
                            .toggleStyle(.button)
                            .tint(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))

                Divider()

                // MARK: Alert list
                if filteredAlerts.isEmpty {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "checkmark.shield.fill",
                        description: Text("All systems operating normally.")
                    )
                } else {
                    List {
                        ForEach(filteredAlerts) { alert in
                            AlertRowView(alert: alert, showResolvButton: !alert.resolved) {
                                fleetVM.resolveAlert(id: alert.id)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { idx in
                                fleetVM.resolveAlert(id: filteredAlerts[idx].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await fleetVM.refreshData()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("System Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !fleetVM.alerts.isEmpty {
                        Text("\(fleetVM.activeAlerts) active")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private func alertColor(_ type: AlertType) -> Color {
        switch type {
        case .speed: return .red
        case .temp:  return .orange
        case .soc:   return .yellow
        }
    }
}
