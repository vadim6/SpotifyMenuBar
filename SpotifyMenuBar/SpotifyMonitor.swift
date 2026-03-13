import Foundation
import Combine

struct SpotifyTrack: Equatable {
    let name: String
    let artist: String
    let isPlaying: Bool
}

class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: SpotifyTrack?

    private var pollingTimer: Timer?
    private let queue = DispatchQueue(label: "com.spotifymenubar.monitor", qos: .utility)

    // Spotify broadcasts these distributed notifications on every state/track change.
    // Subscribing to them means we react instantly with zero polling overhead.
    private let spotifyNotifications = [
        "com.spotify.client.PlaybackStateChanged",
        "com.spotify.client.MetadataChanged",
    ]

    func start() {
        for name in spotifyNotifications {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(spotifyDidChange),
                name: NSNotification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }

        fetchCurrentTrack()

        // Fallback poll every 30 s — catches cases where Spotify was launched after
        // the app started or a notification was missed.
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchCurrentTrack()
        }
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    @objc private func spotifyDidChange() {
        fetchCurrentTrack()
    }

    // MARK: - Private

    private func fetchCurrentTrack() {
        queue.async { [weak self] in
            let track = self?.querySpotify()
            DispatchQueue.main.async {
                self?.currentTrack = track
            }
        }
    }

    private func querySpotify() -> SpotifyTrack? {
        let script = """
tell application "System Events"
    if (name of processes) contains "Spotify" then
        tell application "Spotify"
            if player state is playing then
                return (name of current track) & "|||" & (artist of current track) & "|||playing"
            else if player state is paused then
                return (name of current track) & "|||" & (artist of current track) & "|||paused"
            else
                return "|||stopped"
            end if
        end tell
    else
        return "|||not_running"
    end if
end tell
"""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }

        let state = parts[2]
        guard state == "playing" || state == "paused" else { return nil }

        return SpotifyTrack(name: parts[0], artist: parts[1], isPlaying: state == "playing")
    }
}
