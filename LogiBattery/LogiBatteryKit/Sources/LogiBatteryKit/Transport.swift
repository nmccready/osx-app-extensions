import Foundation
import IOKit.hid

enum TransportError: Error, CustomStringConvertible {
    case receiverNotFound
    case openFailed(IOReturn)

    var description: String {
        switch self {
        case .receiverNotFound: "no Logi Bolt receiver found (vendor 0x046d, usage page 0xFF00, usage 0x02)"
        case .openFailed(let code): "IOHIDDeviceOpen failed: " + String(format: "0x%08x", code)
        }
    }
}

/// Synchronous request/reply over the receiver's HID++ interface. Single threaded: the input report
/// callback is scheduled on the creating thread's run loop and only fires while `send` spins it.
final class HIDPPTransport {
    static let vendorID = 0x046D
    static let hidppUsagePage = 0xFF00
    static let hidppUsage = 0x02
    static let timeout: TimeInterval = 0.5

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var inbox: [[UInt8]] = []

    init() throws {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDDeviceUsagePageKey: Self.hidppUsagePage,
            kIOHIDDeviceUsageKey: Self.hidppUsage,
        ] as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let first = devices.first else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            buffer.deallocate()
            throw TransportError.receiverNotFound
        }
        device = first
        let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            buffer.deallocate()
            throw TransportError.openFailed(opened)
        }
        let callback: IOHIDReportCallback = { context, _, _, _, _, report, length in
            let transport = Unmanaged<HIDPPTransport>.fromOpaque(context!).takeUnretainedValue()
            transport.inbox.append(Array(UnsafeBufferPointer(start: report, count: length)))
        }
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, callback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer.deallocate()
    }

    /// Returns the matching reply, or nil on write failure or timeout. A sleeping device can take
    /// longer than one timeout to wake, so a timeout is retried up to `attempts` times. An explicit
    /// `.unreachable` answer is final.
    func send(_ request: HIDPP.Request, attempts: Int = 1) -> HIDPP.Reply? {
        for _ in 0..<attempts {
            if let reply = sendOnce(request) { return reply }
        }
        return nil
    }

    private func sendOnce(_ request: HIDPP.Request) -> HIDPP.Reply? {
        inbox.removeAll()
        var report = request.report
        let written = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(HIDPP.longReportID), &report, report.count)
        guard written == kIOReturnSuccess else { return nil }
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.02, true)
            while !inbox.isEmpty {
                if let reply = request.interpret(inbox.removeFirst()) { return reply }
            }
        }
        return nil
    }
}
