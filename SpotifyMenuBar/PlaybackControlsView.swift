import AppKit

/// A compact three-button row (previous · play/pause · next) used as a custom
/// NSMenuItem view inside the status-item menu.
final class PlaybackControlsView: NSView {

    var isPlaying = false {
        didSet { updatePlayIcon() }
    }

    var onPrevious:  (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext:      (() -> Void)?

    private let prevBtn = NSButton()
    private let playBtn = NSButton()
    private let nextBtn = NSButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        autoresizingMask = [.width]

        for btn in [prevBtn, playBtn, nextBtn] {
            btn.bezelStyle    = .inline
            btn.isBordered    = false
            btn.imagePosition = .imageOnly
            btn.imageScaling  = .scaleProportionallyDown
            addSubview(btn)
        }

        prevBtn.image = icon("backward.end.fill")
        playBtn.image = icon("play.fill")
        nextBtn.image = icon("forward.end.fill")

        prevBtn.action = #selector(didTapPrev);  prevBtn.target = self
        playBtn.action = #selector(didTapPlay);  playBtn.target = self
        nextBtn.action = #selector(didTapNext);  nextBtn.target = self
    }

    private func icon(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    private func updatePlayIcon() {
        playBtn.image = icon(isPlaying ? "pause.fill" : "play.fill")
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let w = bounds.width / 3
        let h = bounds.height
        prevBtn.frame = NSRect(x: 0,     y: 0, width: w, height: h)
        playBtn.frame = NSRect(x: w,     y: 0, width: w, height: h)
        nextBtn.frame = NSRect(x: w * 2, y: 0, width: w, height: h)
    }

    // MARK: - Actions

    @objc private func didTapPrev() { onPrevious?()  }
    @objc private func didTapPlay() { onPlayPause?() }
    @objc private func didTapNext() { onNext?()      }
}
