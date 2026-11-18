import LogiBatteryKit
import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let readings: [Reading]
}

struct BatteryProvider: TimelineProvider {
    static let refreshInterval: TimeInterval = 15 * 60

    private static let sample: [Reading] = {
        let now = Date()
        return [
            .live(DeviceBattery(slot: 1, name: "MX Keys Mini", kind: .keyboard, percent: 80, charge: .charging), at: now),
            .live(DeviceBattery(slot: 2, name: "MX Master 3S", kind: .mouse, percent: 12, charge: .discharging), at: now),
        ]
    }()

    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: Date(), readings: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        DispatchQueue.global().async {
            completion(BatteryEntry(date: Date(), readings: readAll()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        DispatchQueue.global().async {
            let now = Date()
            let entry = BatteryEntry(date: now, readings: readAll(now: now))
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.refreshInterval))))
        }
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    private var capacity: Int { family == .systemSmall ? 3 : 4 }

    var body: some View {
        if entry.readings.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "cable.connector")
                Text("No Logi devices")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 6) {
                ForEach(entry.readings.prefix(capacity)) { reading in
                    ReadingRow(reading: reading, showsDetail: family != .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct LogiBatteryWidget: Widget {
    let kind = "com.nmccready.LogiBattery.Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Logi Battery")
        .description("Battery level of Logitech devices on a Bolt receiver.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct LogiBatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        LogiBatteryWidget()
    }
}
