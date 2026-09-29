import SwiftUI

// MARK: - ChargingView
// Grid of charging station cards matching the web app's Charging Management tab.

struct ChargingView: View {

    @EnvironmentObject private var fleetVM: FleetViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Summary row
                    HStack(spacing: 16) {
                        SummaryPill(
                            label: "Occupied",
                            value: "\(fleetVM.chargers.filter(\.isOccupied).count)",
                            color: .blue
                        )
                        SummaryPill(
                            label: "Available",
                            value: "\(fleetVM.chargers.filter { !$0.isOccupied }.count)",
                            color: .green
                        )
                        SummaryPill(
                            label: "Total kW",
                            value: "\(fleetVM.chargers.map(\.power).reduce(0, +))",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // MARK: Charger grid
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(fleetVM.chargers) { charger in
                            ChargerCardView(charger: charger)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
            .refreshable {
                await fleetVM.refreshData()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Charging Infrastructure")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - ChargerCardView

private struct ChargerCardView: View {

    let charger: ChargerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(charger.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(charger.locationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(charger.isOccupied ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .foregroundColor(charger.isOccupied ? .blue : .green)
                }
            }

            Divider()

            // Status
            HStack {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(charger.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(charger.isOccupied ? .blue : .green)
            }

            if charger.isOccupied {
                HStack {
                    Text("Vehicle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(charger.currentVehicle ?? "—")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text("Output")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(charger.power) kW")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }

                // Animated charging indicator
                HStack(spacing: 4) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(Color.blue)
                            .frame(height: 6)
                            .opacity(Double(i + 1) * 0.25)
                    }
                }
                .frame(height: 6)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}

// MARK: - SummaryPill

private struct SummaryPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
