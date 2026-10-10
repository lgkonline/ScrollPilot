import Foundation
import IOKit.hid

final class InputDeviceMonitor {
    enum AuthorizationStatus: Equatable {
        case unknown
        case denied
        case granted
    }

    enum DeviceKind: Equatable {
        case magicMouse
        case trackpad
    }

    private var manager: IOHIDManager?
    private var onDeviceActivity: ((DeviceKind) -> Void)?
    private var lastDevice: DeviceKind?

    var authorizationStatus: AuthorizationStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted

        case kIOHIDAccessTypeDenied:
            return .denied

        default:
            return .unknown
        }
    }

    @discardableResult
    func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func start(
        onDeviceActivity: @escaping (DeviceKind) -> Void
    ) -> IOReturn {
        stop()

        self.onDeviceActivity = onDeviceActivity
        lastDevice = nil

        let newManager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        // Wie im erfolgreichen TouchProbe-Test:
        // Manager zuerst öffnen, dann Callback registrieren.
        IOHIDManagerSetDeviceMatching(newManager, nil)

        let result = IOHIDManagerOpen(
            newManager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        guard result == kIOReturnSuccess else {
            self.onDeviceActivity = nil
            return result
        }

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputValueCallback(
            newManager,
            { context, _, _, value in
                guard let context else { return }

                let monitor = Unmanaged<InputDeviceMonitor>
                    .fromOpaque(context)
                    .takeUnretainedValue()

                monitor.handle(value)
            },
            context
        )

        IOHIDManagerScheduleWithRunLoop(
            newManager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )

        manager = newManager
        return result
    }

    func stop() {
        guard let manager else {
            onDeviceActivity = nil
            lastDevice = nil
            return
        }

        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )

        IOHIDManagerClose(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        self.manager = nil
        onDeviceActivity = nil
        lastDevice = nil
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)

        guard let product = IOHIDDeviceGetProperty(
            device,
            kIOHIDProductKey as CFString
        ) else {
            return
        }

        let name = "\(product)".lowercased()
        let kind: DeviceKind

        if name.contains("magic mouse") {
            kind = .magicMouse
        } else if name.contains("trackpad") {
            kind = .trackpad
        } else {
            return
        }

        // Wiederholte Ereignisse desselben Geräts ignorieren.
        guard kind != lastDevice else { return }

        lastDevice = kind
        onDeviceActivity?(kind)
    }

    deinit {
        stop()
    }
}
