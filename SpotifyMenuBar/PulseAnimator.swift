import AppKit

/// Heartbeat-style animation: the centre dot spikes on every beat while a ring
/// bursts outward and fades.  Beat timing is randomised to feel alive.
class PulseAnimator: MenuBarAnimator {

    private struct Ring {
        var progress: CGFloat = 0
        var isActive: Bool    = false
    }

    private var rings     = [Ring(), Ring(), Ring(), Ring()]   // 4 slots → denser overlap
    private var beatIn    = 3
    private var dotScale: CGFloat = 1.0

    private let ringStep: CGFloat  = 0.13    // fast expansion
    private let dotDecay: CGFloat  = 0.70    // sharp fallback to 1.0

    func nextFrame() -> NSImage {
        // Advance all active rings
        for i in rings.indices {
            guard rings[i].isActive else { continue }
            rings[i].progress += ringStep
            if rings[i].progress >= 1 { rings[i].isActive = false }
        }

        // Decay the dot back to its resting size
        dotScale = max(1.0, dotScale * dotDecay)

        // Fire a beat
        beatIn -= 1
        if beatIn <= 0 {
            if let slot = rings.indices.first(where: { !rings[$0].isActive }) {
                rings[slot] = Ring(progress: 0, isActive: true)
            }
            dotScale = 2.4                          // sharp spike
            beatIn   = Int.random(in: 4...10)       // 60–140 BPM at 15 fps
        }

        return render(rings: rings.filter(\.isActive), dotScale: dotScale)
    }

    func stoppedFrame() -> NSImage {
        return render(rings: [], dotScale: 1.0)
    }

    // MARK: - Private

    private func render(rings: [Ring], dotScale: CGFloat) -> NSImage {
        let size = NSSize(width: 14, height: 12)
        let image = NSImage(size: size, flipped: false) { bounds in
            let cx = bounds.midX
            let cy = bounds.midY

            // Centre dot — pops bigger on every beat then snaps back
            NSColor.black.setFill()
            let baseDot: CGFloat = 1.8
            let dotR = min(baseDot * dotScale, 3.8)
            NSBezierPath(ovalIn: NSRect(x: cx - dotR, y: cy - dotR,
                                        width: dotR * 2, height: dotR * 2)).fill()

            // Expanding rings
            let maxR = min(bounds.width, bounds.height) / 2 - 0.5
            for ring in rings {
                let r     = baseDot + ring.progress * (maxR - baseDot)
                let alpha = 1 - ring.progress
                let lw    = max(0.4, 2.0 * (1 - ring.progress))
                NSColor.black.withAlphaComponent(alpha).setStroke()
                let path  = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r,
                                                         width: r * 2, height: r * 2))
                path.lineWidth = lw
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
