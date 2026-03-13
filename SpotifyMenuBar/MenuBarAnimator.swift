import AppKit

protocol MenuBarAnimator: AnyObject {
    /// Called at ~15 fps while a track is playing.
    func nextFrame() -> NSImage
    /// Shown while paused or when no track is loaded.
    func stoppedFrame() -> NSImage
    /// False for NoneAnimator — lets the timer skip animation ticks entirely.
    var isAnimated: Bool { get }
}

/// Static icon — no animation. Reuses the equalizer's stopped frame.
class NoneAnimator: MenuBarAnimator {
    var isAnimated: Bool { false }
    private let frame = EqualizerAnimator().stoppedFrame()
    func nextFrame()    -> NSImage { frame }
    func stoppedFrame() -> NSImage { frame }
}

extension AnimationType {
    func makeAnimator() -> any MenuBarAnimator {
        switch self {
        case .equalizer: return EqualizerAnimator()
        case .soundwave: return SoundwaveAnimator()
        case .pulse:     return PulseAnimator()
        case .none:      return NoneAnimator()
        }
    }
}
