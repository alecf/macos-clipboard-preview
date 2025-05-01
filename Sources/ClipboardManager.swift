import SwiftUI
import Foundation
import SwiftSoup
import Down
import AppKit

class ClipboardManager: ObservableObject {
    @Published var currentContent: String = ""
    @Published var formattedContent: String = ""
    @Published var contentType: ContentType = .plainText
    @Published var windowItems: [WindowItem] = []
    
    private var lastChangeCount: Int
    private var timer: Timer?
    
    enum ContentType {
        case plainText
        case json
        case html
        case css
        case markdown
    }
    
    struct WindowItem: Identifiable {
        let id: UUID
        let title: String
        let content: String
        let window: NSWindow
        
        var previewTitle: String {
            let maxLength = 30
            if content.count > maxLength {
                return String(content.prefix(maxLength)) + "..."
            }
            return content
        }
    }
    
    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
        
        // Set up notification for window closing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        DispatchQueue.main.async {
            self.windowItems.removeAll { $0.window == closedWindow }
        }
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
            currentContent = newString
            detectContentType()
            formatContent()
            createAndShowWindow()
        }
    }
    
    private func createAndShowWindow() {
        DispatchQueue.main.async {
            let contentView = ContentView()
                .environmentObject(self)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Clipboard Preview"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            
            let windowItem = WindowItem(
                id: UUID(),
                title: "Clipboard \(self.windowItems.count + 1)",
                content: self.currentContent,
                window: window
            )
            
            self.windowItems.append(windowItem)
            
            // Ensure we're on the main thread and the app is active
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func showWindow(_ windowItem: WindowItem) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
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
            formattedContent = currentContent
        }
    }
    
    private func formatJSON() {
        guard let data = currentContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            formattedContent = currentContent
            return
        }
        formattedContent = prettyString
    }
    
    private func formatHTML() {
        do {
            let doc = try SwiftSoup.parse(currentContent)
            formattedContent = try doc.outerHtml()
        } catch {
            formattedContent = currentContent
        }
    }
    
    private func formatCSS() {
        // Basic CSS formatting
        var formatted = currentContent
            .replacingOccurrences(of: "{", with: " {\n    ")
            .replacingOccurrences(of: "}", with: "\n}\n")
            .replacingOccurrences(of: ";", with: ";\n    ")
        
        // Clean up extra spaces
        formatted = formatted.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        formattedContent = formatted
    }
    
    private func formatMarkdown() {
        if let down = try? Down(markdownString: currentContent) {
            if let html = try? down.toHTML() {
                formattedContent = html
            } else {
                formattedContent = currentContent
            }
        } else {
            formattedContent = currentContent
        }
    }
} 