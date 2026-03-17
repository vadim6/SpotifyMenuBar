import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an agent app — no Dock icon, no main window
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.cleanup()
    }
}
