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

// Model for a copied URL
struct CopiedURL: Identifiable, Equatable {
    let id: UUID
    var url: String
    var date: Date
    
    static func == (lhs: CopiedURL, rhs: CopiedURL) -> Bool {
        lhs.url == rhs.url
    }
}

// Main clipboard manager that monitors the clipboard and manages windows
class ClipboardManager: ObservableObject {
    @Published var windowItems: [WindowItem] = []
    @Published private(set) var broadcastedJsonPath: String?
    @Published private(set) var broadcastCounter: Int = 0  // Add counter for broadcasts
    @Published var copiedURLs: [CopiedURL] = [] // Global list of copied URLs
    fileprivate var urlListWindow: NSWindow? = nil // Singleton window
    private var urlListWindowDelegate: URLListWindowDelegate? = nil // Strong reference to delegate
    private var lastChangeCount: Int
    private var timer: Timer?
    private var notificationObserver: Any?
    
    // Regex for URL detection
    private let urlRegex = try! NSRegularExpression(pattern: "(https?://[^\\s]+)", options: .caseInsensitive)
    
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
        // If it's a URL, handle it and return (do not open a preview window)
        if isURL(content) {
            checkAndHandleURL(content)
            return
        }
        // Check if we already have a window with this content
        if windowItems.contains(where: { $0.content == content }) {
            // Still check for URL even if duplicate content
            checkAndHandleURL(content)
            return
        }
        
        // Check for URL and handle
        checkAndHandleURL(content)
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Create window item with window reference
        let windowItem = WindowItem(
            id: UUID(),
            title: "Clipboard Preview",
            content: content,
            window: window,  // Include window reference here
            selectedTab: 0
        )
        
        // Create content manager
        let contentManager = WindowContentManager(content: content)
        
        window.title = windowItem.previewTitle
        window.center()
        
        // Create hosting view with environment objects using the windowItem that has the window reference
        let hostingView = NSHostingView(
            rootView: ContentView(windowItem: windowItem)
                .environmentObject(self)
                .environmentObject(contentManager)
        )
        window.contentView = hostingView
        
        // Add to items
        windowItems.append(windowItem)
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func checkAndHandleURL(_ content: String) {
        guard let url = extractURL(from: content) else { return }
        
        if let index = copiedURLs.firstIndex(where: { $0.url == url }) {
            // Update date and move to top
            copiedURLs[index].date = Date()
            let updated = copiedURLs.remove(at: index)
            copiedURLs.insert(updated, at: 0)
        } else {
            // Add new URL to top
            let newURL = CopiedURL(id: UUID(), url: url, date: Date())
            copiedURLs.insert(newURL, at: 0)
        }
        // Open or raise the URL list window
        showOrRaiseURLListWindow()
    }
    
    private func extractURL(from text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = urlRegex.firstMatch(in: text, options: [], range: range) {
            if let urlRange = Range(match.range(at: 1), in: text) {
                return String(text[urlRange])
            }
        }
        return nil
    }
    
    // Helper to check if content is a URL
    private func isURL(_ content: String) -> Bool {
        return extractURL(from: content) != nil
    }
    
    func showOrRaiseURLListWindow() {
        if let window = urlListWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Copied URLs"
        window.center()
        let hostingView = NSHostingView(
            rootView: URLListView()
                .environmentObject(self)
        )
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        urlListWindowDelegate = URLListWindowDelegate(manager: self)
        window.delegate = urlListWindowDelegate
        urlListWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeURLListWindow() {
        urlListWindow?.close()
        urlListWindow = nil
    }
    
    func deleteURL(_ url: CopiedURL) {
        if let index = copiedURLs.firstIndex(of: url) {
            copiedURLs.remove(at: index)
        }
    }
    
    func showWindow(_ windowItem: WindowItem) {
        guard let window = windowItem.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func broadcastJsonPath(_ path: String) {
        DispatchQueue.main.async {
            self.broadcastedJsonPath = path
            self.broadcastCounter += 1  // Increment counter on each broadcast
        }
    }
}

// Delegate to clear the window reference when closed
class URLListWindowDelegate: NSObject, NSWindowDelegate {
    weak var manager: ClipboardManager?
    init(manager: ClipboardManager) { self.manager = manager }
    func windowWillClose(_ notification: Notification) {
        manager?.urlListWindow = nil
    }
} 