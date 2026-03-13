import AppKit

/// Generates menu-bar-sized equalizer images (14×12 pt, template).
/// Call `nextFrame()` at ~15 fps while playing; `stoppedFrame()` when paused/idle.
class EqualizerAnimator: MenuBarAnimator {

    private let numBars = 4
    private var heights: [CGFloat]      // 0.0 … 1.0 (normalised)
    private var velocities: [CGFloat]   // change per frame tick

    init() {
        heights    = [0.45, 0.80, 0.55, 0.90]
        velocities = [ 0.08, -0.11,  0.09, -0.07]
    }

    // MARK: - Public

    func nextFrame() -> NSImage {
        for i in 0..<numBars {
            heights[i] += velocities[i]
            if heights[i] >= 1.0 {
                heights[i] = 1.0
                velocities[i] = -CGFloat.random(in: 0.06...0.13)
            } else if heights[i] <= 0.10 {
                heights[i] = 0.10
                velocities[i] =  CGFloat.random(in: 0.06...0.13)
            }
        }
        return render(heights: heights)
    }

    /// Four short equal bars — used when paused or no track.
    func stoppedFrame() -> NSImage {
        return render(heights: [0.25, 0.25, 0.25, 0.25])
    }

    // MARK: - Private

    private func render(heights: [CGFloat]) -> NSImage {
        let size = NSSize(width: 14, height: 12)

        let image = NSImage(size: size, flipped: false) { bounds in
            let barW: CGFloat  = 2.5
            let gap: CGFloat   = 1.0
            let totalW = CGFloat(self.numBars) * barW + CGFloat(self.numBars - 1) * gap
            let startX = (bounds.width - totalW) / 2.0

            NSColor.black.setFill()

            for i in 0..<self.numBars {
                let x = startX + CGFloat(i) * (barW + gap)
                let h = max(2.0, heights[i] * bounds.height)
                // Anchor bars to the bottom of the canvas
                let rect = NSRect(x: x, y: 0, width: barW, height: h)
                NSBezierPath(roundedRect: rect, xRadius: 1.0, yRadius: 1.0).fill()
            }
            return true
        }

        // Template images automatically adapt to dark/light mode and menu-bar tint
        image.isTemplate = true
        return image
    }
}
