import SwiftUI

// MARK: - AlertRowView
// Reusable alert row used on Dashboard and AlertsView.

struct AlertRowView: View {

    let alert: AlertModel
    var showResolvButton: Bool = false
    var onResolve: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: alert.type.systemImageName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 17))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.busId)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(alert.timeAgoString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(iconColor)

                if alert.resolved {
                    Label("Resolved", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            // Resolve button
            if showResolvButton {
                Button {
                    onResolve?()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(iconColor.opacity(0.06))
        .cornerRadius(14)
        .opacity(alert.resolved ? 0.5 : 1.0)
    }

    private var iconColor: Color {
        switch alert.type {
        case .speed: return .red
        case .temp:  return .orange
        case .soc:   return Color(hex: "#F59E0B") ?? .yellow
        }
    }
}
