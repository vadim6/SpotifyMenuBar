import AppKit

protocol MenuBarAnimator: AnyObject {
    /// Called at ~15 fps while a track is playing.
    func nextFrame() -> NSImage
    /// Shown while paused or when no track is loaded.
    func stoppedFrame() -> NSImage
}

extension AnimationType {
    func makeAnimator() -> any MenuBarAnimator {
        switch self {
        case .equalizer: return EqualizerAnimator()
        case .soundwave: return SoundwaveAnimator()
        case .pulse:     return PulseAnimator()
        }
    }
}
