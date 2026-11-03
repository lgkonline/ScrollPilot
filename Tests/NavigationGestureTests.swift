import CoreGraphics
import IOKit.hidsystem
import Testing
@testable import NavigationGestures

struct NavigationGestureTests {
    @Test func windowsAppReceivesNavigationShortcuts() {
        let remapper = NavigationGestureRemapper()
        for (mask, direction): (Int64, NavigationGestureDecoder.Direction) in [(4, .left), (8, .right)] {
            #expect(remapper.navigationDecision(
                frontmostBundleIdentifier: "com.microsoft.rdc.macos",
                eventType: 29, hidType: 16, swipeMask: mask, phase: 0
            ) == .init(suppress: true, direction: direction))
        }
    }

    @Test func otherAndUnknownAppsKeepNativeGestures() {
        let remapper = NavigationGestureRemapper()
        for identifier: String? in [nil, "", "com.apple.Safari", "Windows App", "Microsoft Remote Desktop.app", "com.microsoft.rdc.macos.helper"] {
            for phase: Int64 in [0, 1, 2, 4, 8] {
                #expect(remapper.navigationDecision(
                    frontmostBundleIdentifier: identifier,
                    eventType: 29, hidType: 16, swipeMask: 4, phase: phase
                ) == .init())
            }
        }
    }

    @Test func leavingWindowsAppResetsGestureState() {
        for otherApp: String? in ["com.apple.Safari", nil] {
            let remapper = NavigationGestureRemapper()
            #expect(remapper.navigationDecision(
                frontmostBundleIdentifier: "com.microsoft.rdc.macos",
                eventType: 29, hidType: 16, swipeMask: 4, phase: 1
            ).direction == .left)
            #expect(remapper.navigationDecision(
                frontmostBundleIdentifier: otherApp,
                eventType: 29, hidType: 16, swipeMask: 4, phase: 2
            ) == .init())
            #expect(remapper.navigationDecision(
                frontmostBundleIdentifier: "com.microsoft.rdc.macos",
                eventType: 29, hidType: 16, swipeMask: 0, phase: 4
            ) == .init())
            #expect(remapper.navigationDecision(
                frontmostBundleIdentifier: "com.microsoft.rdc.macos",
                eventType: 29, hidType: 16, swipeMask: 8, phase: 1
            ).direction == .right)
        }
    }

    @Test func horizontalDirections() {
        var decoder = NavigationGestureDecoder()
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 0)
            == .init(suppress: true, direction: .left))
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 8, phase: 0)
            == .init(suppress: true, direction: .right))
    }

    @Test func oneShortcutPerGesture() {
        var decoder = NavigationGestureDecoder()
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 1).direction == .left)
        for _ in 0..<10 {
            #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 2)
                == .init(suppress: true))
        }
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 0, phase: 4)
            == .init(suppress: true))
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 8, phase: 1).direction == .right)
    }

    @Test func delayedDirection() {
        var decoder = NavigationGestureDecoder()
        #expect(!decoder.process(eventType: 29, hidType: 16, swipeMask: 0, phase: 1).suppress)
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 8, phase: 4).direction == .right)
    }

    @Test func unrelatedEventsPassThrough() {
        for eventType: UInt32 in [22, 30, 31] {
            var decoder = NavigationGestureDecoder()
            #expect(decoder.process(eventType: eventType, hidType: 16, swipeMask: 4, phase: 1) == .init())
        }
        for hidType: Int64 in [5, 6, 8, 11, 22, 23, 27] {
            var decoder = NavigationGestureDecoder()
            #expect(decoder.process(eventType: 29, hidType: hidType, swipeMask: 4, phase: 1) == .init())
        }
        for mask: Int64 in [0, 1, 2, 3, 5, 12, 16, 255] {
            var decoder = NavigationGestureDecoder()
            #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: mask, phase: 1) == .init())
        }
    }

    @Test func cancellationAndUnknownPhases() {
        var decoder = NavigationGestureDecoder()
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 8) == .init())
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 256) == .init())
        _ = decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 1)
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 8) == .init(suppress: true))
        #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 8, phase: 1).direction == .right)
    }

    @Test func resetAndSeriesBoundaries() {
        for boundary: Int64 in [61, 62] {
            var decoder = NavigationGestureDecoder()
            _ = decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 1)
            #expect(decoder.process(eventType: 29, hidType: boundary, swipeMask: 0, phase: 0) == .init())
            #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 8, phase: 2).direction == .right)
            decoder.reset()
            #expect(decoder.process(eventType: 29, hidType: 16, swipeMask: 4, phase: 2).direction == .left)
        }
    }

    @Test func balancedKeyboardEvents() {
        for (direction, key): (NavigationGestureDecoder.Direction, CGKeyCode) in [(.left, 123), (.right, 124)] {
            for optionHeld in [false, true] {
                let strokes = NavigationGestureRemapper.keyStrokes(for: direction, leftOptionHeld: optionHeld)
                #expect(strokes.count == (optionHeld ? 2 : 4))
                let expectedFlags = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK)))
                let arrows = strokes.filter { $0.keyCode == key }
                #expect(arrows.count == 2)
                #expect(arrows[0].isDown)
                #expect(!arrows[1].isDown)
                #expect(arrows.allSatisfy { $0.flags == expectedFlags })
                let options = strokes.filter { $0.keyCode == 58 }
                #expect(options.count == (optionHeld ? 0 : 2))
                if options.count == 2 {
                    #expect(options[0].isDown && options[0].flags == expectedFlags)
                    #expect(!options[1].isDown && options[1].flags.isEmpty)
                }
            }
        }
    }

    @Test func heldRightOptionIsNotReleasedOrChangedToLeftOption() {
        let strokes = NavigationGestureRemapper.keyStrokes(for: .left, rightOptionHeld: true)
        let expected = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK)))
        #expect(strokes.count == 2)
        #expect(strokes.allSatisfy { $0.keyCode == 123 && $0.flags == expected })
    }

    @Test func bothHeldOptionKeysRetainTheirSideFlags() {
        let strokes = NavigationGestureRemapper.keyStrokes(for: .right, leftOptionHeld: true, rightOptionHeld: true)
        let expected = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK)))
        #expect(strokes.count == 2)
        #expect(strokes.allSatisfy { $0.keyCode == 124 && $0.flags == expected })
    }

    @Test func stopIsIdempotent() {
        let remapper = NavigationGestureRemapper()
        remapper.stop()
        remapper.stop()
        #expect(!remapper.isRunning)
    }
}
