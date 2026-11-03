import AppKit
import ApplicationServices
import Carbon.HIToolbox
import IOKit.hidsystem

/// All access, including the event-tap callback, occurs on the main run loop.
final class NavigationGestureRemapper {
    enum StartResult {
        case started
        case accessibilityRequired
        case failed
    }

    private static let keyboardModifiers: CGEventFlags = [
        .maskAlternate, .maskCommand, .maskControl, .maskShift,
        CGEventFlags(rawValue: UInt64(
            NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK |
            NX_DEVICELCMDKEYMASK | NX_DEVICERCMDKEYMASK |
            NX_DEVICELCTLKEYMASK | NX_DEVICERCTLKEYMASK |
            NX_DEVICELSHIFTKEYMASK | NX_DEVICERSHIFTKEYMASK
        ))
    ]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var decoder = NavigationGestureDecoder()
    var onFailure: (() -> Void)?

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    static var hasAccess: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func start() -> StartResult {
        if isRunning { return .started }
        stop()
        guard Self.hasAccess else { return .accessibilityRequired }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << 29,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<NavigationGestureRemapper>
                    .fromOpaque(context).takeUnretainedValue()
                    .handle(type: type, event: event)
            },
            userInfo: context
        ) else { return .failed }

        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return .failed
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        return .started
    }

    func stop() {
        if let tap { CFMachPortInvalidate(tap) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        decoder.reset()
    }

    private func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            decoder.reset()
            if Self.hasAccess, let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if isRunning { return Unmanaged.passUnretained(event) }
            }
            fail()
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            fail()
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 29 else { return Unmanaged.passUnretained(event) }

        // Private Quartz gesture fields, isolated here for OS compatibility.
        // Definitions: WebKit/Tools/TestRunnerShared/spi/CoreGraphicsTestSPI.h.
        // Only HID navigationSwipe (16) is decoded; scroll, zoom, rotation,
        // and Dock/Spaces gestures are intentionally not intercepted.
        guard let hidField = CGEventField(rawValue: 110),
              let directionField = CGEventField(rawValue: 115),
              let phaseField = CGEventField(rawValue: 132) else {
            return Unmanaged.passUnretained(event)
        }
        let decision = navigationDecision(
            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            eventType: type.rawValue,
            hidType: event.getIntegerValueField(hidField),
            swipeMask: event.getIntegerValueField(directionField),
            phase: event.getIntegerValueField(phaseField)
        )
        if let direction = decision.direction {
            guard let events = Self.keyEvents(for: direction) else {
                fail()
                return Unmanaged.passUnretained(event)
            }
            // Enter at HID level so clients with earlier keyboard taps can receive
            // the shortcut too. This tap only subscribes to gestures, not keys.
            for keyEvent in events { keyEvent.post(tap: .cghidEventTap) }
        }
        return decision.suppress ? nil : Unmanaged.passUnretained(event)
    }

    func navigationDecision(
        frontmostBundleIdentifier: String?,
        eventType: UInt32,
        hidType: Int64,
        swipeMask: Int64,
        phase: Int64
    ) -> NavigationGestureDecoder.Decision {
        // Match the bundle identity, not the app's filename or localized name.
        guard frontmostBundleIdentifier == "com.microsoft.rdc.macos" else {
            decoder.reset()
            return .init()
        }
        return decoder.process(
            eventType: eventType, hidType: hidType, swipeMask: swipeMask, phase: phase
        )
    }

    private static func keyEvents(for direction: NavigationGestureDecoder.Direction) -> [CGEvent]? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        let option = CGKeyCode(kVK_Option)
        let leftOptionHeld = CGEventSource.keyState(.combinedSessionState, key: option)
        let rightOptionHeld = CGEventSource.keyState(
            .combinedSessionState, key: CGKeyCode(kVK_RightOption)
        )
        var events: [CGEvent] = []
        for (keyCode, isDown, flags) in keyStrokes(
            for: direction, leftOptionHeld: leftOptionHeld, rightOptionHeld: rightOptionHeld
        ) {
            guard let event = CGEvent(
                keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown
            ) else { return nil }
            // Keep the constructor's arrow-key flags (numeric pad / Fn).
            // Replacing all flags loses information consumed by remote clients.
            event.flags = event.flags.subtracting(keyboardModifiers).union(flags)
            events.append(event)
        }
        return events
    }

    static func keyStrokes(
        for direction: NavigationGestureDecoder.Direction,
        leftOptionHeld: Bool = false,
        rightOptionHeld: Bool = false
    ) -> [(keyCode: CGKeyCode, isDown: Bool, flags: CGEventFlags)] {
        let key = CGKeyCode(direction == .left ? kVK_LeftArrow : kVK_RightArrow)
        let option = CGKeyCode(kVK_Option)
        // Include the device-dependent side bits as real Option events do.
        // In particular, remote clients may distinguish left Alt from right Alt.
        let optionHeld = leftOptionHeld || rightOptionHeld
        var optionFlags = CGEventFlags.maskAlternate
        if !optionHeld || leftOptionHeld {
            optionFlags.insert(CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK)))
        }
        if rightOptionHeld {
            optionFlags.insert(CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK)))
        }
        var strokes: [(CGKeyCode, Bool, CGEventFlags)] = []
        if !optionHeld { strokes.append((option, true, optionFlags)) }
        strokes.append((key, true, optionFlags))
        strokes.append((key, false, optionFlags))
        if !optionHeld { strokes.append((option, false, [])) }
        return strokes
    }

    private func fail() {
        stop()
        onFailure?()
    }

    deinit { stop() }
}
