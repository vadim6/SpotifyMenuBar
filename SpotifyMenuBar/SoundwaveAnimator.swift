import AppKit

/// Symmetric vertical bars — tall in the centre, short at the edges — each bar
/// animating independently toward a random target.  Matches the "audio waveform"
/// look in the reference image.
class SoundwaveAnimator: MenuBarAnimator {
    var isAnimated: Bool { true }

    private let numBars  = 9
    /// Gaussian-ish envelope: constrains how tall each column can grow.
    private let envelope: [CGFloat] = [0.15, 0.38, 0.65, 0.88, 1.0, 0.88, 0.65, 0.38, 0.15]

    private var heights: [CGFloat]
    private var targets: [CGFloat]

    init() {
        heights = [0.12, 0.32, 0.55, 0.72, 0.85, 0.72, 0.55, 0.32, 0.12]
        targets = heights
    }

    func nextFrame() -> NSImage {
        for i in 0..<numBars {
            // Smooth lerp toward target
            heights[i] += (targets[i] - heights[i]) * 0.28

            // Each bar independently picks a new target at random
            if CGFloat.random(in: 0...1) < 0.13 {
                targets[i] = envelope[i] * CGFloat.random(in: 0.12...1.0)
            }
        }
        return render(heights: heights)
    }

    func stoppedFrame() -> NSImage {
        return render(heights: envelope.map { $0 * 0.18 })
    }

    // MARK: - Private

    private func render(heights: [CGFloat]) -> NSImage {
        // Render at 2× logical size so bars map pixel-perfectly on Retina.
        // MenuBarController draws this into the 14×12 pt icon slot, scaling it back down.
        let scale: CGFloat = 2
        let size = NSSize(width: 14 * scale, height: 12 * scale)   // 28 × 24

        let image = NSImage(size: size, flipped: false) { bounds in
            let midY  = bounds.midY
            // Scale bar geometry with the canvas
            let barW: CGFloat = 2.4        // 1.2 × 2
            let gap:  CGFloat = 0.9        // wider gap prevents inter-bar bleed
            let totalW = CGFloat(self.numBars) * barW + CGFloat(self.numBars - 1) * gap
            let startX = (bounds.width - totalW) / 2

            NSColor.black.setFill()

            for i in 0..<self.numBars {
                let x = startX + CGFloat(i) * (barW + gap)
                let h = max(scale, heights[i] * bounds.height * 0.48)
                let rect = NSRect(x: x, y: midY - h, width: barW, height: h * 2)
                // Radius ~30 % of bar width — visible capsule cap without turning short bars into blobs
                NSBezierPath(roundedRect: rect, xRadius: 0.75, yRadius: 0.75).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
