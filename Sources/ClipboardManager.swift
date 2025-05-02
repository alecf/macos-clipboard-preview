import SwiftUI
import Foundation
import SwiftSoup
import Down
import AppKit

public struct WindowItem: Identifiable {
    public let id: UUID
    public let title: String
    public let content: String
    public let window: NSWindow
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
}

class ClipboardManager: ObservableObject {
    @Published var currentContent: String = ""
    @Published var formattedContent: String = ""
    @Published var contentType: ContentType = .plainText
    @Published var windowItems: [WindowItem] = []
    @Published var hasFormattedContent: Bool = false
    @Published var broadcastedJsonPath: String? = nil  // New property for broadcasting
    
    private var lastChangeCount: Int
    private var timer: Timer?
    private var notificationObserver: Any?
    
    enum ContentType {
        case plainText
        case json
        case html
        case css
        case markdown
    }
    
    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        
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
        
        // Check initial clipboard content
        if let initialContent = NSPasteboard.general.string(forType: .string) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Check if we already have a window with this content
                if let existingItem = self.windowItems.first(where: { $0.content == initialContent }) {
                    existingItem.window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
                
                self.hasFormattedContent = false  // Reset before processing new content
                self.currentContent = initialContent
                self.detectContentType()
                self.formatContent()
                self.createAndShowWindow()
            }
        }
        
        startMonitoring()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
        
        // Clean up windows
        for item in windowItems {
            item.window.close()
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
            DispatchQueue.main.async {
                // Check if we already have a window with this content
                if let existingItem = self.windowItems.first(where: { $0.content == newString }) {
                    existingItem.window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
                
                self.hasFormattedContent = false  // Reset before processing new content
                self.currentContent = newString
                self.detectContentType()
                self.formatContent()
                self.createAndShowWindow()
            }
        }
    }
    
    private func createAndShowWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let windowItem = WindowItem(
                id: UUID(),
                title: "Clipboard \(self.windowItems.count + 1)",
                content: self.currentContent,
                window: NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                ),
                selectedTab: 0  // Start with preview tab
            )
            
            windowItem.window.title = "Clipboard Preview"
            windowItem.window.contentView = NSHostingView(rootView: ContentView(windowItem: windowItem)
                .environmentObject(self))
            windowItem.window.center()
            windowItem.window.isReleasedWhenClosed = false
            
            self.windowItems.append(windowItem)
            
            windowItem.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showWindow(_ windowItem: WindowItem) {
        DispatchQueue.main.async {
            windowItem.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func detectContentType() {
        // Try JSON
        if let data = currentContent.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            contentType = .json
            return
        }
        
        // Try HTML
        if currentContent.lowercased().contains("<!doctype html") ||
           currentContent.lowercased().contains("<html") {
            contentType = .html
            return
        }
        
        // Try CSS
        if currentContent.contains("{") &&
           currentContent.contains("}") &&
           currentContent.contains(":") {
            let cssIndicators = ["margin", "padding", "color", "background", "font-"]
            if cssIndicators.contains(where: { currentContent.lowercased().contains($0) }) {
                contentType = .css
                return
            }
        }
        
        // Try Markdown
        let markdownIndicators = ["#", "##", "```", "**", "__", "- ", "* ", "> "]
        if markdownIndicators.contains(where: { currentContent.contains($0) }) {
            contentType = .markdown
            return
        }
        
        contentType = .plainText
    }
    
    private func formatContent() {
        // Reset formatted content
        formattedContent = currentContent
        hasFormattedContent = contentType != .plainText  // Set based on content type
        
        switch contentType {
        case .json:
            formatJSON()
        case .html:
            formatHTML()
        case .css:
            formatCSS()
        case .markdown:
            formatMarkdown()
        case .plainText:
            break
        }
    }
    
    private func formatJSON() {
        guard let data = currentContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            hasFormattedContent = false  // Only set to false if formatting fails
            return
        }
        
        formattedContent = prettyString
    }
    
    private func formatHTML() {
        do {
            let doc = try SwiftSoup.parse(currentContent)
            formattedContent = try doc.outerHtml()
        } catch {
            hasFormattedContent = false  // Only set to false if formatting fails
        }
    }
    
    private func formatCSS() {
        var formatted = currentContent
            .replacingOccurrences(of: "{", with: " {\n    ")
            .replacingOccurrences(of: "}", with: "\n}\n")
            .replacingOccurrences(of: ";", with: ";\n    ")
        
        formatted = formatted.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        formattedContent = formatted
    }
    
    private func formatMarkdown() {
        if let down = try? Down(markdownString: currentContent),
           let html = try? down.toHTML() {
            formattedContent = html
        } else {
            hasFormattedContent = false  // Only set to false if formatting fails
        }
    }
    
    // Add new method for broadcasting JSONPath
    func broadcastJsonPath(_ path: String) {
        print("Broadcasting JSONPath: \(path)")  // Debug log
        DispatchQueue.main.async {
            self.broadcastedJsonPath = path
            print("Set broadcastedJsonPath to: \(path)")  // Debug log
            // Reset after a short delay to allow new broadcasts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("Resetting broadcastedJsonPath")  // Debug log
                self.broadcastedJsonPath = nil
            }
        }
    }
} 