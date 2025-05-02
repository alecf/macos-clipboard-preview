import SwiftUI
import Foundation
import SwiftSoup
import Down
import AppKit

public struct WindowItem: Identifiable {
    public let id: UUID
    public let title: String
    public let content: String
    public let window: NSWindow?
    public var selectedTab: Int
    
    public var previewTitle: String {
        let maxLength = 30
        // First, drop all leading whitespace
        let noLeadingWhitespace = content.drop(while: { $0.isWhitespace })
        if noLeadingWhitespace.count > maxLength {
            return String(noLeadingWhitespace.prefix(maxLength)) + "..."
        }
        return String(noLeadingWhitespace)
    }
    
    public mutating func updateSelectedTab(_ tab: Int) {
        selectedTab = tab
    }
    
    init(id: UUID, title: String, content: String, window: NSWindow? = nil, selectedTab: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.window = window
        self.selectedTab = selectedTab
    }
}

// Manages content for a single window
class WindowContentManager: ObservableObject {
    enum ContentType {
        case plainText
        case json
        case html
        case css
        case markdown
    }
    
    @Published private(set) var currentContent: String
    @Published private(set) var contentType: ContentType
    @Published private(set) var formattedContent: String
    @Published private(set) var broadcastedJsonPath: String?
    
    init(content: String) {
        self.currentContent = content
        self.contentType = Self.detectContentType(content)
        self.formattedContent = content // Initialize with raw content first
        self.broadcastedJsonPath = nil
        // Now format the content after all properties are initialized
        self.formattedContent = Self.formatContent(content, type: self.contentType)
    }
    
    var hasFormattedContent: Bool {
        contentType != .plainText
    }
    
    func broadcastJsonPath(_ path: String) {
        broadcastedJsonPath = path
    }
    
    private static func detectContentType(_ content: String) -> ContentType {
        // Try parsing as JSON first
        if let data = content.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            return .json
        }
        
        // Check for HTML
        if content.lowercased().contains("<!doctype html>") ||
            content.lowercased().contains("<html") {
            return .html
        }
        
        // Check for CSS
        if content.contains("{") && content.contains("}") &&
            (content.contains("px") || content.contains("em") || content.contains("rgb")) {
            return .css
        }
        
        // Check for Markdown
        if content.contains("#") || content.contains("```") ||
            content.contains("**") || content.contains("__") {
            return .markdown
        }
        
        return .plainText
    }
    
    private static func formatContent(_ content: String, type: ContentType) -> String {
        switch type {
        case .json:
            if let data = content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let formattedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let formattedString = String(data: formattedData, encoding: .utf8) {
                return formattedString
            }
        case .html, .css:
            // For HTML and CSS, we could add proper indentation in the future
            return content
        case .markdown, .plainText:
            return content
        }
        return content
    }
}

// Main clipboard manager that monitors the clipboard and manages windows
class ClipboardManager: ObservableObject {
    @Published var windowItems: [WindowItem] = []
    private var lastChangeCount: Int
    private var timer: Timer?
    private var notificationObserver: Any?
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // Set up notification for window closing
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let closedWindow = notification.object as? NSWindow else { return }
            self.windowItems.removeAll { $0.window == closedWindow }
        }
        
        // Start monitoring after initialization
        DispatchQueue.main.async { [weak self] in
            self?.startMonitoring()
            
            // Check initial clipboard content after a brief delay
            if let initialContent = NSPasteboard.general.string(forType: .string) {
                self?.processNewContent(initialContent)
            }
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
        
        // Clean up windows
        for item in windowItems {
            item.window?.close()
        }
        windowItems.removeAll()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        if let newString = pasteboard.string(forType: .string) {
            DispatchQueue.main.async { [weak self] in
                self?.processNewContent(newString)
            }
        }
    }
    
    private func processNewContent(_ content: String) {
        // Check if we already have a window with this content
        if windowItems.contains(where: { $0.content == content }) {
            return
        }
        
        // Create window item
        let windowItem = WindowItem(
            id: UUID(),
            title: "Clipboard Preview",
            content: content,
            selectedTab: 0
        )
        
        // Create content manager
        let contentManager = WindowContentManager(content: content)
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = windowItem.previewTitle
        window.center()
        
        // Create hosting view with environment objects
        let hostingView = NSHostingView(
            rootView: ContentView(windowItem: windowItem)
                .environmentObject(self)
                .environmentObject(contentManager)
        )
        window.contentView = hostingView
        
        // Store window reference and add to items
        windowItems.append(WindowItem(
            id: windowItem.id,
            title: windowItem.title,
            content: content,
            window: window,
            selectedTab: windowItem.selectedTab
        ))
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showWindow(_ windowItem: WindowItem) {
        guard let window = windowItem.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
} 