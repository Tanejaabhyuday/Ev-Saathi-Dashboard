import SwiftUI

// MARK: - FleetStatusView
// Searchable, filterable list of all buses. Tap to open BusDetailView.

struct FleetStatusView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel
    @State private var searchQuery: String = ""
    @State private var filterStatus: BusStatus? = nil
    @State private var selectedBusId: String?

    private var filteredBuses: [BusModel] {
        fleetVM.buses.filter { bus in
            let matchesStatus = filterStatus == nil || bus.status == filterStatus
            let q = searchQuery.lowercased()
            let matchesSearch = q.isEmpty
                || bus.id.lowercased().contains(q)
                || bus.driverName.lowercased().contains(q)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(label: "All", isSelected: filterStatus == nil) {
                            filterStatus = nil
                        }
                        ForEach(BusStatus.allCases, id: \.self) { status in
                            FilterChip(label: status.rawValue, isSelected: filterStatus == status,
                                       color: statusColor(status)) {
                                filterStatus = filterStatus == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))

                Divider()

                // MARK: Bus list
                if fleetVM.buses.isEmpty {
                    ProgressView("Loading fleet data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredBuses.isEmpty {
                    ContentUnavailableView("No Buses Found",
                                          systemImage: "bus",
                                          description: Text("Try changing your search or filter."))
                } else {
                    List(filteredBuses) { bus in
                        Button {
                            selectedBusId = bus.id
                        } label: {
                            BusRowView(bus: bus)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await fleetVM.refreshData()
                    }
                }
            }
            .navigationTitle("Fleet Status")
            .searchable(text: $searchQuery, prompt: "Search bus ID or driver…")
            .navigationDestination(item: $selectedBusId) { busId in
                BusDetailView(busId: busId)
                    .environmentObject(fleetVM)
            }
        }
    }

    private func statusColor(_ status: BusStatus) -> Color {
        switch status {
        case .moving:   return .blue
        case .charging: return .green
        case .alert:    return .red
        case .idle:     return .gray
        }
    }
}

// MARK: - BusRowView

private struct BusRowView: View {

    let bus: BusModel

    var body: some View {
        HStack(spacing: 14) {
            // Status dot + icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bus.fill")
                    .foregroundColor(statusColor)
                    .font(.system(size: 18))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(bus.id)
                        .font(.system(.headline, design: .monospaced))
                    Spacer()
                    StatusBadge(status: bus.status)
                }
                Text(bus.driverName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Label("\(Int(bus.soc))%", systemImage: "battery.75")
                    Label("\(Int(bus.speed)) km/h", systemImage: "gauge")
                    Label("\(Int(bus.temp))°C", systemImage: "thermometer")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // SOC progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5)).frame(height: 4)
                        Capsule()
                            .fill(bus.soc < 20 ? Color.red : Color.green)
                            .frame(width: geo.size.width * CGFloat(bus.soc / 100), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch bus.status {
        case .moving:   return .blue
        case .charging: return .green
        case .alert:    return .red
        case .idle:     return .gray
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .orange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
                .foregroundColor(isSelected ? color : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: BusStatus
    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.12))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }
    private var badgeColor: Color {
        switch status {
        case .moving:   return .blue
        case .charging: return .green
        case .alert:    return .red
        case .idle:     return .gray
        }
    }
}
