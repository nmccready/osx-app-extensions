import Foundation
import Testing
@testable import LogiBatteryKit

private func report(id: UInt8 = 0x11, slot: UInt8, feature: UInt8, function: UInt8, swid: UInt8 = HIDPP.softwareID, params: [UInt8] = []) -> [UInt8] {
    var bytes = [id, slot, feature, (function << 4) | swid] + params
    bytes += [UInt8](repeating: 0, count: 20 - bytes.count)
    return bytes
}

@Suite("requests")
struct RequestTests {
    @Test func longReportLayout() {
        let request = HIDPP.Request(slot: 2, featureIndex: 7, function: 1, params: [0x05])
        #expect(request.report == [0x11, 2, 7, 0x1A, 0x05] + [UInt8](repeating: 0, count: 15))
    }

    @Test func getFeatureEncodesBigEndianID() {
        let request = HIDPP.getFeature(slot: 1, .unifiedBattery)
        #expect(Array(request.report.prefix(6)) == [0x11, 1, 0x00, 0x0A, 0x10, 0x04])
    }
}

@Suite("reply matching")
struct MatchingTests {
    let request = HIDPP.Request(slot: 1, featureIndex: 9, function: 1)

    @Test func matchingReplyReturnsPayload() {
        let reply = request.interpret(report(slot: 1, feature: 9, function: 1, params: [60, 3, 0]))
        #expect(reply == .payload([60, 3, 0] + [UInt8](repeating: 0, count: 13)))
    }

    @Test func laggingReplyForAnotherSlotIsDiscarded() {
        #expect(request.interpret(report(slot: 2, feature: 9, function: 1, params: [75])) == nil)
    }

    @Test func laggingReplyForAnotherFeatureIsDiscarded() {
        #expect(request.interpret(report(slot: 1, feature: 4, function: 1, params: [75])) == nil)
    }

    @Test func laggingReplyForAnotherFunctionIsDiscarded() {
        #expect(request.interpret(report(slot: 1, feature: 9, function: 0, params: [75])) == nil)
    }

    @Test func replyToAnotherSoftwareIDIsDiscarded() {
        #expect(request.interpret(report(slot: 1, feature: 9, function: 1, swid: 0x03, params: [75])) == nil)
    }

    @Test func shortReportIsDiscarded() {
        #expect(request.interpret([0x10, 1, 9]) == nil)
    }

    @Test func hidpp1UnreachableErrorForThisRequest() {
        let error: [UInt8] = [0x10, 1, 0x8F, 9, 0x1A, 0x04, 0x00]
        #expect(request.interpret(error) == .unreachable)
    }

    @Test func hidpp1ErrorForAnotherSlotIsDiscarded() {
        let error: [UInt8] = [0x10, 2, 0x8F, 9, 0x1A, 0x04, 0x00]
        #expect(request.interpret(error) == nil)
    }

    @Test func hidpp1ErrorForAnEarlierRequestIsDiscarded() {
        let error: [UInt8] = [0x10, 1, 0x8F, 0, 0x0A, 0x04, 0x00]
        #expect(request.interpret(error) == nil)
    }

    @Test func hidpp2ErrorForThisRequest() {
        let error = [0x11, 1, 0xFF, 9, 0x1A, 0x05] + [UInt8](repeating: 0, count: 14)
        #expect(request.interpret(error) == .unreachable)
    }

    @Test func hidpp2ErrorForAnEarlierRequestIsDiscarded() {
        let error = [0x11, 1, 0xFF, 4, 0x0A, 0x05] + [UInt8](repeating: 0, count: 14)
        #expect(request.interpret(error) == nil)
    }
}

@Suite("decoding")
struct DecodeTests {
    @Test func missingFeatureIsIndexZero() {
        #expect(HIDPP.decodeFeatureIndex([0, 0, 0]) == nil)
        #expect(HIDPP.decodeFeatureIndex([6, 0, 0]) == 6)
        #expect(HIDPP.decodeFeatureIndex([]) == nil)
    }

    @Test func nameIsReassembledAcrossZeroPaddedChunks() {
        let name = Array("MX Keys Mini for Mac".utf8)
        let chunks = stride(from: 0, to: name.count, by: 16).map { start in
            Array(name[start..<min(start + 16, name.count)]) + [UInt8](repeating: 0, count: max(0, start + 16 - name.count))
        }
        var bytes: [UInt8] = []
        for chunk in chunks where bytes.count < name.count {
            bytes += HIDPP.decodeNameChunk(chunk, remaining: name.count - bytes.count)
        }
        #expect(chunks.count == 2)
        #expect(HIDPP.decodeName(bytes) == "MX Keys Mini for Mac")
    }

    @Test func nameLengthIsFirstByte() {
        #expect(HIDPP.decodeNameLength([12, 0]) == 12)
        #expect(HIDPP.decodeNameLength([]) == nil)
    }

    @Test func kindCodes() {
        #expect(HIDPP.decodeKind([0]) == .keyboard)
        #expect(HIDPP.decodeKind([3]) == .mouse)
        #expect(HIDPP.decodeKind([7]) == .receiver)
        #expect(HIDPP.decodeKind([42]) == .unknown)
        #expect(HIDPP.decodeKind([]) == .unknown)
    }

    @Test(arguments: [
        (UInt8(0), ChargeState.discharging), (1, .charging), (2, .charging), (3, .full), (4, .unknown), (9, .unknown),
    ])
    func unifiedBatteryChargeStates(code: UInt8, expected: ChargeState) {
        let decoded = HIDPP.decodeBattery([60, 8, code, 0])
        #expect(decoded?.percent == 60)
        #expect(decoded?.charge == expected)
    }

    @Test(arguments: [
        (UInt8(0), ChargeState.discharging), (1, .charging), (2, .charging), (3, .full), (5, .unknown),
    ])
    func batteryStatusFallbackStates(code: UInt8, expected: ChargeState) {
        let decoded = HIDPP.decodeBattery([75, 50, code, 0])
        #expect(decoded?.percent == 75)
        #expect(decoded?.charge == expected)
    }

    @Test func percentIsClampedAndShortPayloadRejected() {
        #expect(HIDPP.decodeBattery([200, 0, 0])?.percent == 100)
        #expect(HIDPP.decodeBattery([50, 0]) == nil)
    }
}

@Suite("merge")
struct MergeTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    let t1 = Date(timeIntervalSince1970: 2_000)
    let mouse = DeviceBattery(slot: 1, name: "MX Master 3S", kind: .mouse, percent: 60, charge: .discharging)
    let keyboard = DeviceBattery(slot: 2, name: "MX Keys Mini for Mac", kind: .keyboard, percent: 75, charge: .discharging)

    @Test func sleepingDeviceKeepsLastValueAsStale() {
        let previous: [Reading] = [.live(mouse, at: t0), .live(keyboard, at: t0)]
        let merged = merge(live: [mouse], previous: previous, now: t1)
        #expect(merged == [.live(mouse, at: t1), .stale(keyboard, lastSeen: t0)])
    }

    @Test func liveReadingReplacesCachedValue() {
        let lower = DeviceBattery(slot: 1, name: mouse.name, kind: .mouse, percent: 55, charge: .discharging)
        let merged = merge(live: [lower], previous: [.live(mouse, at: t0)], now: t1)
        #expect(merged == [.live(lower, at: t1)])
    }

    @Test func staleStaysStaleWithOriginalDate() {
        let merged = merge(live: [], previous: [.stale(keyboard, lastSeen: t0)], now: t1)
        #expect(merged == [.stale(keyboard, lastSeen: t0)])
    }

    @Test func resultIsOrderedBySlot() {
        let merged = merge(live: [keyboard, mouse], previous: [], now: t1)
        #expect(merged.map(\.id) == [1, 2])
    }

    @Test func readingSurvivesCodableRoundTrip() throws {
        let readings: [Reading] = [.live(mouse, at: t0), .stale(keyboard, lastSeen: t1)]
        let data = try JSONEncoder().encode(readings)
        #expect(try JSONDecoder().decode([Reading].self, from: data) == readings)
    }
}
