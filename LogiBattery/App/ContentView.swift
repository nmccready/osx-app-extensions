import LogiBatteryKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var readings: [Reading] = BatteryCache.standard.load()
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if readings.isEmpty {
                ContentUnavailableView(
                    "No devices",
                    systemImage: "cable.connector",
                    description: Text("Plug in the Logi Bolt receiver and press Refresh.")
                )
            } else {
                List(readings) { reading in
                    ReadingRow(reading: reading, showsDetail: true)
                        .padding(.vertical, 4)
                }
            }
            HStack {
                Button("Refresh", action: refresh)
                    .disabled(isRefreshing)
                if isRefreshing { ProgressView().controlSize(.small) }
            }
        }
        .padding()
        .task { refresh() }
    }

    private func refresh() {
        isRefreshing = true
        Task {
            readings = await Task.detached { readAll() }.value
            WidgetCenter.shared.reloadAllTimelines()
            isRefreshing = false
        }
    }
}
