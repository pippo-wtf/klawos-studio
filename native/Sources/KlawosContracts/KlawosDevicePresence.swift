import Foundation
import IOKit
import IOKit.hid

public enum KlawosDevicePresence {
    /// Registry lookup only: no device open, HID reports, or subprocesses. Match
    /// the same vendor/product and raw-HID interface used by KlawosProbe.
    public static var isPresent: Bool {
        let matching: [String: Any] = [
            kIOProviderClassKey: "IOHIDDevice",
            kIOPropertyMatchKey: [
                kIOHIDVendorIDKey: 0x5241,
                kIOHIDProductIDKey: 0x1234,
                kIOHIDPrimaryUsagePageKey: 0xff60,
                kIOHIDPrimaryUsageKey: 0x61
            ]
        ]
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching as CFDictionary)
        guard service != 0 else { return false }
        IOObjectRelease(service)
        return true
    }
}
