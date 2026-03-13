import Foundation
import CoreGraphics

/// Pixel-accurate ping-pong scroller.
/// Call `configure` when text/width change, then `advance(dt:enabled:)` every frame.
/// Read `offset` to translate the drawing origin.
class SmoothScroller {

    private(set) var offset:    CGFloat = 0
    private(set) var maxOffset: CGFloat = 0

    private var direction:  CGFloat  = 1   // +1 forward, -1 backward
    private var phase               = Phase.waitingAtStart(elapsed: 0)

    let speed:       CGFloat       = 38   // points per second
    let startPause:  TimeInterval  = 2.0
    let endPause:    TimeInterval  = 1.5

    private enum Phase {
        case waitingAtStart(elapsed: TimeInterval)
        case scrolling
        case waitingAtEnd(elapsed: TimeInterval)
    }

    // MARK: - Public

    /// Call when the full text width or the visible window width changes.
    func configure(textWidth: CGFloat, visibleWidth: CGFloat) {
        let newMax = max(0, textWidth - visibleWidth)
        guard abs(newMax - maxOffset) > 0.5 else { return }
        maxOffset = newMax
        reset()
    }

    func reset() {
        offset    = 0
        direction = 1
        phase     = .waitingAtStart(elapsed: 0)
    }

    /// Advance by `dt` seconds. No-op when scrolling is disabled or text fits.
    func advance(dt: TimeInterval, enabled: Bool) {
        guard enabled, maxOffset > 0 else { return }

        switch phase {
        case .waitingAtStart(let elapsed):
            let next = elapsed + dt
            if next >= startPause { phase = .scrolling }
            else                  { phase = .waitingAtStart(elapsed: next) }

        case .scrolling:
            offset += direction * speed * CGFloat(dt)
            if offset >= maxOffset {
                offset = maxOffset
                phase  = .waitingAtEnd(elapsed: 0)
            } else if offset <= 0 {
                offset = 0
                phase  = .waitingAtEnd(elapsed: 0)
            }

        case .waitingAtEnd(let elapsed):
            let next = elapsed + dt
            if next >= endPause {
                direction *= -1
                phase      = .scrolling
            } else {
                phase = .waitingAtEnd(elapsed: next)
            }
        }
    }
}
