import Foundation
import Combine

enum AnimationType: String, CaseIterable {
    case equalizer = "Equalizer"
    case soundwave = "Soundwave"
    case pulse     = "Pulse"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var scrollingEnabled: Bool {
        didSet { UserDefaults.standard.set(scrollingEnabled, forKey: Keys.scrolling) }
    }

    @Published var animationType: AnimationType {
        didSet { UserDefaults.standard.set(animationType.rawValue, forKey: Keys.animation) }
    }

    private enum Keys {
        static let scrolling  = "scrollingEnabled"
        static let animation  = "animationType"
    }

    private init() {
        UserDefaults.standard.register(defaults: [Keys.scrolling: true])
        scrollingEnabled = UserDefaults.standard.bool(forKey: Keys.scrolling)
        let raw = UserDefaults.standard.string(forKey: Keys.animation) ?? ""
        animationType = AnimationType(rawValue: raw) ?? .equalizer
    }
}
