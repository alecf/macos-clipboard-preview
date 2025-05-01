import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (shows in menu bar, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Disable automatic window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window is closed
        return false
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Ensure we stay in accessory mode when inactive
        NSApp.setActivationPolicy(.accessory)
    }
} 