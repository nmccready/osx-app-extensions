import Foundation
import LogiBatteryKit

for reading in readAll() {
    let battery = reading.battery
    let state = reading.isStale
        ? "asleep, last seen \(reading.date.formatted(date: .abbreviated, time: .shortened))"
        : battery.charge.rawValue
    print("slot \(battery.slot)  \(battery.name)  [\(battery.kind)]  \(battery.percent)%  \(state)")
}
