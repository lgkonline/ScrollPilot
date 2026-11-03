/// Decodes discrete page-navigation gestures, never scroll-wheel or Dock gestures.
struct NavigationGestureDecoder {
    enum Direction: Equatable {
        case left
        case right
    }

    struct Decision: Equatable {
        let suppress: Bool
        let direction: Direction?

        init(suppress: Bool = false, direction: Direction? = nil) {
            self.suppress = suppress
            self.direction = direction
        }
    }

    private var handledGesture = false

    mutating func reset() {
        handledGesture = false
    }

    mutating func process(
        eventType: UInt32,
        hidType: Int64,
        swipeMask: Int64,
        phase: Int64
    ) -> Decision {
        guard eventType == 29 else { return Decision() }

        // These HID types bracket a gesture series, including non-navigation gestures.
        if hidType == 61 || hidType == 62 {
            reset()
            return Decision()
        }
        guard hidType == 16 else { return Decision() }
        guard [0, 1, 2, 4, 8, 128].contains(phase) else {
            reset()
            return Decision()
        }

        if phase == 1 || phase == 128 {
            reset()
        }
        if phase == 8 {
            let suppress = handledGesture
            reset()
            return Decision(suppress: suppress)
        }

        let direction: Direction?
        switch swipeMask {
        case 4: direction = .left
        case 8: direction = .right
        default: direction = nil
        }

        // Unknown/vertical directions pass through. A directionless end belongs
        // to our gesture only if its horizontal navigation was already handled.
        let suppress = handledGesture || direction != nil
        let output = handledGesture ? nil : direction
        if direction != nil {
            handledGesture = true
        }
        if phase == 4 || phase == 0 {
            reset()
        }
        return Decision(suppress: suppress, direction: output)
    }
}
