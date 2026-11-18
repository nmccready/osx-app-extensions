# LogiBattery

A macOS widget that shows the battery level of Logitech devices paired to a Logi Bolt USB receiver.

Apple's Batteries widget only lists Bluetooth devices, so it skips anything on a Bolt receiver. Logi Options+ reads those batteries over Logitech's HID++ 2.0 protocol. LogiBattery does the same, from a sandboxed app and a WidgetKit extension.

## What you get

- A `systemSmall` and `systemMedium` widget. Each device shows an SF Symbol for its type, its percent, and a bolt while charging. Anything at 15% or lower turns red.
- A small app that lists the same readings and has a Refresh button. Refresh also reloads the widget timeline.
- A sleeping device keeps its last value, dimmed, with an "asleep" note, instead of vanishing.
- A `logi-battery` command line tool that prints the readings.

The widget refreshes every 15 minutes.

## Requirements

- macOS 15 or later, with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- An "Apple Development" certificate in your login keychain.
- A Logi Bolt receiver. Bluetooth-connected Logitech devices are not read.

## Build

```bash
LogiBattery/scripts/build.sh
```

`build.sh` reads your team ID from the Apple Development certificate and writes it to `LogiBattery/Local.xcconfig`, which is gitignored. It then runs `xcodegen` and `xcodebuild` in Release. The result is `LogiBattery/build/Build/Products/Release/LogiBattery.app`.

`LogiBattery/project.yml` is the source of truth. The `.xcodeproj` and the `Generated/` entitlements and Info.plist files are produced from it and not committed.

## Install

```bash
LogiBattery/scripts/install.sh
```

This copies the app to `/Applications/LogiBattery.app`, registers it with Launch Services, and opens it once so macOS discovers the widget. It only replaces an app whose bundle ID is `com.nmccready.LogiBattery`.

## Add the widget

1. Right-click the desktop, or open Notification Center, and choose Edit Widgets.
2. Search for "Logi Battery".
3. Pick the small or medium size and add it.

If the widget is missing from the gallery, run `pluginkit -m -v -i com.nmccready.LogiBattery.Widget` to confirm it is registered, then log out and back in.

## Command line tool

```bash
cd LogiBattery/LogiBatteryKit
swift run logi-battery
```

Example output.

```text
slot 1  MX Keys Mini for Mac  [keyboard]  80%  charging
slot 2  MX Master 3S  [mouse]  60%  discharging
```

A device that did not answer prints as `asleep, last seen <date>` with its cached value.

## Tests

```bash
cd LogiBattery/LogiBatteryKit
swift test
```

The tests cover the pure decode layer. That includes reply matching, the HID++ error replies, device name chunking, both battery features, and merging live readings with the cache. They do not need a receiver.

## How it works

- `LogiBatteryKit` is a local Swift package. `HIDPP.swift` encodes requests and decodes replies with no IOKit. `Transport.swift` is the IOKit side. `Reader.swift` exposes `readAll() -> [Reading]`.
- The receiver's HID++ interface is the one with usage page `0xFF00` and usage `0x02`, vendor `0x046d`. Matching on `kIOHIDPrimaryUsagePageKey` finds nothing, so the transport matches `kIOHIDDeviceUsagePageKey` and `kIOHIDDeviceUsageKey`.
- Each slot, 1 to 6, is asked for its name and type (feature `0x0005`), then its battery from `0x1004` Unified Battery, falling back to `0x1000` Battery Status.
- A reply counts only when its slot, feature index, and function match the request. Late or unsolicited reports are discarded. A `0x8F` or `0xFF` error that echoes the request marks the slot unreachable.
- A sleeping device can take longer than one 500 ms timeout to wake, so the first request to a slot retries up to three times.
- The app and the widget each open the receiver themselves. Both need the `com.apple.security.device.usb` entitlement, since a sandboxed process without it fails to open the device with `0xe00002e2`. No helper process or App Group is involved.
- Each process caches its last readings in its own sandbox `UserDefaults`. The app and the widget do not share a cache.

## Troubleshooting

- `no Logi Bolt receiver found` in the log means the receiver is not plugged in, or another vendor ID is in use.
- `IOHIDDeviceOpen failed: 0xe00002e2` means the binary was signed without the USB entitlement. Check it with `codesign -d --entitlements - /Applications/LogiBattery.app`.
- To watch the app read the devices, run `log show --predicate 'subsystem == "com.nmccready.LogiBattery"' --last 2m --info`. In zsh, call `/usr/bin/log`, since `log` is a shell builtin.
- A device that never answers on a slot shows its last cached value as asleep. A device you unpaired keeps showing that way until you remove `~/Library/Containers/com.nmccready.LogiBattery`, which holds the cache.
