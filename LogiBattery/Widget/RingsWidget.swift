import LogiBatteryKit
import SwiftUI
import WidgetKit

struct RingsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    private static let slots = 4

    private var cells: [Reading?] {
        let shown = entry.readings.prefix(Self.slots).map(Optional.some)
        return shown + Array(repeating: nil, count: Self.slots - shown.count)
    }

    var body: some View {
        if family == .systemSmall {
            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow { ring(0, diameter: 38); ring(1, diameter: 38) }
                GridRow { ring(2, diameter: 38); ring(3, diameter: 38) }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<Self.slots, id: \.self) { index in
                    ring(index, diameter: 56)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func ring(_ index: Int, diameter: CGFloat) -> some View {
        BatteryRing(reading: cells[index], diameter: diameter)
            .frame(width: diameter + 24)
    }
}

struct LogiBatteryRingsWidget: Widget {
    let kind = "com.nmccready.LogiBattery.Rings"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryProvider()) { entry in
            RingsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Logi Battery Rings")
        .description("Battery rings for Logitech devices on a Bolt receiver.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
