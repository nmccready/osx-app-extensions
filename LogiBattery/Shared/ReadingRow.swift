import LogiBatteryKit
import SwiftUI

extension DeviceKind {
    var symbolName: String {
        switch self {
        case .keyboard, .numpad: "keyboard"
        case .mouse, .trackball: "computermouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .remote, .presenter: "av.remote"
        case .receiver: "cable.connector"
        case .unknown: "questionmark.circle"
        }
    }
}

extension Reading {
    static let lowBatteryThreshold = 15

    var isLow: Bool { battery.percent <= Self.lowBatteryThreshold }
}

/// One device line shared by the app window and the widget families.
struct ReadingRow: View {
    let reading: Reading
    var showsDetail = false

    var body: some View {
        let battery = reading.battery
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: battery.kind.symbolName)
                    .frame(width: 18)
                Text(battery.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if battery.charge == .charging {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                }
                Text("\(battery.percent)%")
                    .monospacedDigit()
                    .bold()
                    .foregroundStyle(reading.isLow ? Color.red : Color.primary)
            }
            if showsDetail {
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(reading.isLow ? Color.red : Color.accentColor)
                                .frame(width: proxy.size.width * CGFloat(min(max(battery.percent, 0), 100)) / 100)
                        }
                    }
                    .frame(height: 4)
                if reading.isStale {
                    Text("asleep, last seen \(reading.date, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .opacity(reading.isStale ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }
}
