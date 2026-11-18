import LogiBatteryKit
import SwiftUI

/// Apple Batteries style cell: progress ring around the device icon, percent and name below.
/// A nil reading draws an empty ring so the grid keeps its shape.
struct BatteryRing: View {
    let reading: Reading?
    var diameter: CGFloat = 50

    private var lineWidth: CGFloat { diameter / 10 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: lineWidth)
                if let reading {
                    let battery = reading.battery
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(battery.percent, 0), 100)) / 100)
                        .stroke(reading.isLow ? Color.red : Color.green,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: battery.kind.symbolName)
                        .font(.system(size: diameter * 0.36))
                    if battery.charge == .charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: diameter * 0.2))
                            .foregroundStyle(.green)
                            .offset(y: diameter * 0.3)
                    }
                }
            }
            .frame(width: diameter, height: diameter)

            Text(reading.map { "\($0.battery.percent)%" } ?? " ")
                .font(.system(size: diameter * 0.26, weight: .semibold))
                .monospacedDigit()
            Text(reading?.battery.name ?? " ")
                .font(.system(size: max(9, diameter * 0.18)))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .opacity(reading?.isStale == true ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }
}
