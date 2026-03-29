import SwiftUI
import MacCleanerCore

struct APFSBreakdownView: View {
    let volumes: [APFSVolume]
    let containerTotal: Int64
    let containerFree: Int64

    private let roleColors: [String: Color] = [
        "Data": .blue,
        "VM": .orange,
        "Preboot": .purple,
        "System": .gray,
        "Recovery": .green,
    ]

    private let roleIcons: [String: String] = [
        "Data": "externaldrive.fill",
        "VM": "memorychip",
        "Preboot": "power",
        "System": "gearshape.fill",
        "Recovery": "cross.circle.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APFS Volume Breakdown")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Volume bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(volumes, id: \.name) { vol in
                        let fraction = containerTotal > 0
                            ? CGFloat(vol.consumedBytes) / CGFloat(containerTotal)
                            : 0
                        if fraction > 0.01 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill((roleColors[vol.role] ?? .gray).gradient)
                                .frame(width: max(4, geo.size.width * fraction))
                                .help("\(vol.name) (\(vol.role)): \(ByteCountFormatter.string(fromByteCount: vol.consumedBytes, countStyle: .file))")
                        }
                    }
                    // Free space
                    let freeFraction = containerTotal > 0
                        ? CGFloat(containerFree) / CGFloat(containerTotal)
                        : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: max(4, geo.size.width * freeFraction))
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Volume legend with details
            VStack(spacing: 6) {
                ForEach(volumes, id: \.name) { vol in
                    HStack(spacing: 8) {
                        Image(systemName: roleIcons[vol.role] ?? "questionmark.circle")
                            .foregroundStyle(roleColors[vol.role] ?? .gray)
                            .frame(width: 16)

                        Text(vol.name)
                            .font(.caption)
                            .frame(width: 120, alignment: .leading)

                        Text(vol.role)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 60, alignment: .leading)

                        Spacer()

                        Text(ByteCountFormatter.string(fromByteCount: vol.consumedBytes, countStyle: .file))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(warningColor(for: vol))

                        // Warning for abnormal sizes
                        if let warning = warningText(for: vol) {
                            Text(warning)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Free space row
                HStack(spacing: 8) {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text("Free Space")
                        .font(.caption)
                        .frame(width: 120, alignment: .leading)

                    Text("")
                        .frame(width: 60)

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: containerFree, countStyle: .file))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(containerFree < 20_000_000_000 ? .red : .green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func warningColor(for vol: APFSVolume) -> Color {
        switch vol.role {
        case "VM" where vol.consumedBytes > 10_000_000_000:
            return .orange
        case "Preboot" where vol.consumedBytes > 5_000_000_000:
            return .orange
        default:
            return .primary
        }
    }

    private func warningText(for vol: APFSVolume) -> String? {
        switch vol.role {
        case "VM" where vol.consumedBytes > 10_000_000_000:
            return "High! Restart Mac to free"
        case "Preboot" where vol.consumedBytes > 5_000_000_000:
            return "Abnormally large"
        default:
            return nil
        }
    }
}
