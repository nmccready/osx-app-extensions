import Foundation
import os

let logger = Logger(subsystem: "com.nmccready.LogiBattery", category: "read")

/// Last readings, persisted in the calling process's own `UserDefaults` (the sandbox container for
/// the app and for the widget, each separately).
public struct BatteryCache {
    private let defaults: UserDefaults
    private let key = "logiBattery.readings"

    public static let standard = BatteryCache(defaults: .standard)

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [Reading] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Reading].self, from: data)) ?? []
    }

    func save(_ readings: [Reading]) {
        if let data = try? JSONEncoder().encode(readings) {
            defaults.set(data, forKey: key)
        }
    }
}

/// Live batteries win. Any other slot seen before keeps its last value as `.stale`.
func merge(live: [DeviceBattery], previous: [Reading], now: Date) -> [Reading] {
    var bySlot: [UInt8: Reading] = [:]
    for reading in previous {
        bySlot[reading.id] = .stale(reading.battery, lastSeen: reading.date)
    }
    for battery in live {
        bySlot[battery.slot] = .live(battery, at: now)
    }
    return bySlot.values.sorted { $0.id < $1.id }
}

/// Reads every paired device on the Bolt receiver and merges the result with the cache.
/// Blocks for up to a few seconds while the receiver answers, so call it off the main thread.
public func readAll(cache: BatteryCache = .standard, now: Date = Date()) -> [Reading] {
    let live: [DeviceBattery]
    do {
        let transport = try HIDPPTransport()
        live = HIDPP.slots.compactMap { readSlot($0, via: transport) }
    } catch {
        logger.error("receiver unavailable: \(String(describing: error), privacy: .public)")
        live = []
    }
    let readings = merge(live: live, previous: cache.load(), now: now)
    cache.save(readings)
    for reading in readings {
        let battery = reading.battery
        logger.notice("slot \(battery.slot) \(battery.name, privacy: .public) \(battery.percent)% \(battery.charge.rawValue, privacy: .public) stale=\(reading.isStale)")
    }
    return readings
}

private func featureIndex(_ feature: HIDPP.Feature, slot: UInt8, attempts: Int = 1, via transport: HIDPPTransport) -> UInt8? {
    guard case .payload(let params)? = transport.send(HIDPP.getFeature(slot: slot, feature), attempts: attempts) else { return nil }
    return HIDPP.decodeFeatureIndex(params)
}

private func payload(_ request: HIDPP.Request, via transport: HIDPPTransport) -> [UInt8]? {
    guard case .payload(let params)? = transport.send(request) else { return nil }
    return params
}

private func readName(slot: UInt8, index: UInt8, via transport: HIDPPTransport) -> String? {
    guard let length = payload(.init(slot: slot, featureIndex: index, function: 0), via: transport)
        .flatMap(HIDPP.decodeNameLength) else { return nil }
    var bytes: [UInt8] = []
    while bytes.count < length {
        let request = HIDPP.Request(slot: slot, featureIndex: index, function: 1, params: [UInt8(bytes.count)])
        guard let params = payload(request, via: transport) else { return nil }
        let chunk = HIDPP.decodeNameChunk(params, remaining: length - bytes.count)
        if chunk.isEmpty { break }
        bytes += chunk
    }
    return HIDPP.decodeName(bytes)
}

/// nil when the slot is empty, asleep, or the device has no battery feature.
private func readSlot(_ slot: UInt8, via transport: HIDPPTransport) -> DeviceBattery? {
    guard let nameIndex = featureIndex(.deviceName, slot: slot, attempts: 3, via: transport),
          let name = readName(slot: slot, index: nameIndex, via: transport) else { return nil }
    let kind = payload(.init(slot: slot, featureIndex: nameIndex, function: 2), via: transport)
        .map(HIDPP.decodeKind) ?? .unknown

    let status: (percent: Int, charge: ChargeState)?
    if let index = featureIndex(.unifiedBattery, slot: slot, via: transport) {
        status = payload(.init(slot: slot, featureIndex: index, function: 1), via: transport).flatMap(HIDPP.decodeBattery)
    } else if let index = featureIndex(.batteryStatus, slot: slot, via: transport) {
        status = payload(.init(slot: slot, featureIndex: index, function: 0), via: transport).flatMap(HIDPP.decodeBattery)
    } else {
        status = nil
    }
    guard let status else { return nil }
    return DeviceBattery(slot: slot, name: name, kind: kind, percent: status.percent, charge: status.charge)
}
