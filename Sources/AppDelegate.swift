import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app can show windows even though it's a background app
        NSApp.setActivationPolicy(.regular)
        
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
    }
} 