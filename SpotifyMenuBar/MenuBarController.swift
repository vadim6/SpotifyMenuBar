import AppKit
import Combine

class MenuBarController: NSObject {

    private let statusItem: NSStatusItem
    private let monitor   = SpotifyMonitor()
    private let settings  = AppSettings.shared
    private let scroller  = SmoothScroller()

    private var animator: any MenuBarAnimator
    private var currentAnimFrame: NSImage

    private var displayTimer: Timer?
    private var isPlaying = false

    // Cached to avoid re-measuring on every frame
    private var currentFullTitle = ""
    private var cachedAttrStr:   NSAttributedString?
    private var cachedTextWidth: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    // Layout constants
    private let iconSize    = NSSize(width: 14, height: 12)
    private let iconTextGap: CGFloat = 4
    private let textAreaW:  CGFloat  = 200
    private let barHeight:  CGFloat  = 16

    // Menu items
    private let trackNameItem = NSMenuItem(title: "Not playing", action: nil, keyEquivalent: "")
    private let artistItem    = NSMenuItem(title: "",            action: nil, keyEquivalent: "")
    private var scrollMenuItem: NSMenuItem!
    private var animMenuItems = [AnimationType: NSMenuItem]()

    // MARK: - Init

    override init() {
        let initType     = AppSettings.shared.animationType
        animator         = initType.makeAnimator()
        currentAnimFrame = animator.stoppedFrame()
        statusItem       = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        setupButton()
        setupMenu()
        setupSettingsObservers()
        setupMonitor()
        monitor.start()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: "music.note",
                               accessibilityDescription: "Spotify")
    }

    private func setupMenu() {
        let menu = NSMenu()

        trackNameItem.isEnabled = false
        artistItem.isEnabled    = false

        menu.addItem(trackNameItem)
        menu.addItem(artistItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Spotify",
                                  action: #selector(openSpotify), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        scrollMenuItem = NSMenuItem(title: "Scroll Title",
                                    action: #selector(toggleScrolling), keyEquivalent: "")
        scrollMenuItem.target = self
        scrollMenuItem.state  = settings.scrollingEnabled ? .on : .off
        menu.addItem(scrollMenuItem)

        let animSub = NSMenu()
        for type in AnimationType.allCases {
            let item = NSMenuItem(title: type.rawValue,
                                  action: #selector(selectAnimation(_:)), keyEquivalent: "")
            item.target            = self
            item.representedObject = type.rawValue
            item.state             = (type == settings.animationType) ? .on : .off
            animSub.addItem(item)
            animMenuItems[type] = item
        }
        let animParent = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        animParent.submenu = animSub
        menu.addItem(animParent)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpotifyMenuBar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupSettingsObservers() {
        settings.$scrollingEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                self.scrollMenuItem?.state = enabled ? .on : .off
                self.scroller.reset()
                self.renderButton()
                self.restartDisplayTimer()
            }
            .store(in: &cancellables)

        settings.$animationType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                guard let self else { return }
                for (t, item) in self.animMenuItems { item.state = (t == type) ? .on : .off }
                self.animator         = type.makeAnimator()
                self.currentAnimFrame = self.isPlaying
                    ? self.animator.nextFrame()
                    : self.animator.stoppedFrame()
                self.renderButton()
            }
            .store(in: &cancellables)
    }

    private func setupMonitor() {
        monitor.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.update(with: track) }
            .store(in: &cancellables)
    }

    // MARK: - Track update

    private func update(with track: SpotifyTrack?) {
        guard let track else {
            isPlaying        = false
            currentFullTitle = ""
            cachedAttrStr    = nil
            cachedTextWidth  = 0
            scroller.configure(textWidth: 0, visibleWidth: textAreaW)
            stopDisplayTimer()
            statusItem.button?.image = NSImage(systemSymbolName: "music.note",
                                               accessibilityDescription: "Spotify")
            trackNameItem.title = "Not playing"
            artistItem.title    = ""
            return
        }

        let newTitle = "\(track.artist) – \(track.name)"
        isPlaying    = track.isPlaying
        trackNameItem.title = track.name
        artistItem.title    = track.artist.isEmpty ? "" : "by \(track.artist)"

        if newTitle != currentFullTitle {
            currentFullTitle = newTitle
            let font  = NSFont.menuBarFont(ofSize: 0)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            cachedAttrStr   = NSAttributedString(string: currentFullTitle, attributes: attrs)
            cachedTextWidth = cachedAttrStr!.size().width
            scroller.configure(textWidth: cachedTextWidth, visibleWidth: textAreaW)
        }

        currentAnimFrame = isPlaying ? animator.nextFrame() : animator.stoppedFrame()
        renderButton()         // render immediately — don't wait for the first tick
        restartDisplayTimer()  // start only if there is something ongoing to animate/scroll
    }

    // MARK: - Display timer (15 fps)

    /// Only runs when there is ongoing work: animation (playing) or scrolling (long title).
    /// Completely idle otherwise — no CPU cost when paused or Spotify is closed.
    private func restartDisplayTimer() {
        stopDisplayTimer()
        let needsAnimation = isPlaying
        let needsScrolling = settings.scrollingEnabled && scroller.maxOffset > 0
        guard needsAnimation || needsScrolling else { return }

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func tick() {
        let prevOffset = scroller.offset
        scroller.advance(dt: 1.0 / 15.0, enabled: settings.scrollingEnabled)
        let scrollMoved = scroller.offset != prevOffset

        if isPlaying {
            currentAnimFrame = animator.nextFrame()
            renderButton()
        } else if scrollMoved {
            // Paused but scrolling — only re-render when position actually changed
            renderButton()
        }
    }

    // MARK: - Composite rendering

    private func renderButton() {
        guard let button = statusItem.button,
              let attrStr = cachedAttrStr else { return }

        let visibleW = min(cachedTextWidth, textAreaW)
        let txtH     = attrStr.size().height
        let offset   = scroller.offset

        let textImg = NSImage(size: NSSize(width: visibleW, height: barHeight),
                              flipped: false) { [attrStr] bounds in
            NSBezierPath(rect: bounds).addClip()
            attrStr.draw(at: CGPoint(x: -offset, y: (bounds.height - txtH) / 2))
            return true
        }

        let totalW = iconSize.width + iconTextGap + visibleW
        let composite = NSImage(size: NSSize(width: totalW, height: barHeight),
                                flipped: false) { [weak self] bounds in
            guard let self else { return false }
            let iconY = (bounds.height - self.iconSize.height) / 2
            self.currentAnimFrame.draw(
                in: NSRect(x: 0, y: iconY, width: self.iconSize.width, height: self.iconSize.height),
                from: .zero, operation: .sourceOver, fraction: 1)
            textImg.draw(
                in: NSRect(x: self.iconSize.width + self.iconTextGap, y: 0,
                           width: visibleW, height: self.barHeight),
                from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        composite.isTemplate = true

        button.imagePosition = .imageOnly
        button.image         = composite
    }

    // MARK: - Menu actions

    @objc private func toggleScrolling() {
        settings.scrollingEnabled.toggle()
    }

    @objc private func selectAnimation(_ sender: NSMenuItem) {
        guard let raw  = sender.representedObject as? String,
              let type = AnimationType(rawValue: raw) else { return }
        settings.animationType = type
    }

    @objc private func openSpotify() {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) {
            NSWorkspace.shared.openApplication(at: url,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: - Teardown

    func cleanup() {
        stopDisplayTimer()
        monitor.stop()
    }
}
