import SwiftUI
import Down
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var contentManager: WindowContentManager
    let windowItem: WindowItem
    @State private var selectedTab: Int
    
    init(windowItem: WindowItem) {
        self.windowItem = windowItem
        _selectedTab = State(initialValue: windowItem.selectedTab)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Preview Tab
            PreviewTab(content: contentManager.currentContent,
                      contentType: contentManager.contentType)
                .tabItem {
                    Label("Preview", systemImage: "eye")
                }
                .tag(0)
            
            // Formatted Tab
            FormattedTab(content: contentManager.formattedContent,
                        contentType: contentManager.contentType,
                        windowItem: windowItem)
                .tabItem {
                    Label("Formatted", systemImage: "wand.and.stars")
                }
                .tag(1)
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding()
        .onAppear {
            // Set initial tab based on content only for new windows
            if selectedTab == 0 && contentManager.hasFormattedContent {
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Update the window item's selected tab
            if let index = clipboardManager.windowItems.firstIndex(where: { $0.id == windowItem.id }) {
                clipboardManager.windowItems[index].selectedTab = newValue
            }
        }
    }
}

struct PreviewTab: View {
    let content: String
    let contentType: WindowContentManager.ContentType
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Content Type: \(String(describing: contentType))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                switch contentType {
                case .html:
                    WebView(htmlString: content)
                case .markdown:
                    if let down = try? Down(markdownString: content),
                       let attributedString = try? down.toAttributedString() {
                        Text(AttributedString(attributedString))
                    } else {
                        Text(content)
                    }
                default:
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FormattedTab: View {
    let content: String
    let contentType: WindowContentManager.ContentType
    @State private var jsonRoot: JSONTreeNode?
    @State private var selectedPath: String = "$"
    @EnvironmentObject var contentManager: WindowContentManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    @StateObject private var viewState = ViewState()
    let windowItem: WindowItem
    
    class ViewState: ObservableObject {
        @Published var coordinator: JSONTreeView.Coordinator?
        
        func setCoordinator(_ newCoordinator: JSONTreeView.Coordinator) {
            coordinator = newCoordinator
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Formatted Content")
                    .font(.headline)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            
            if contentType == .json {
                Text(selectedPath)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            
            if contentType == .json, let root = jsonRoot {
                JSONTreeView(rootNode: .constant(root), selectedPath: $selectedPath,
                           onCoordinatorCreated: { newCoordinator in
                    viewState.setCoordinator(newCoordinator)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                List(clipboardManager.copiedURLs) { urlItem in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(urlItem.url)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(urlItem.date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            clipboardManager.deleteURL(urlItem)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .onAppear {
            if contentType == .json {
                createJSONTree()
            }
        }
        .onChange(of: clipboardManager.broadcastCounter) { oldValue, newValue in
            if contentType == .json, // Only handle if we're showing JSON
               let path = clipboardManager.broadcastedJsonPath,
               let currentCoordinator = viewState.coordinator,
               let outlineView = currentCoordinator.outlineView {
                // Try to find the node at the path
                if let node = findNode(path: path, in: jsonRoot) {
                    selectedPath = path
                    currentCoordinator.selectItemWithPath(path, in: outlineView)
                    
                    // Raise this window more aggressively
                    if let window = windowItem.window {
                        // First make sure the app is active
                        NSApp.activate(ignoringOtherApps: true)
                        
                        // Force window to front
                        window.orderFrontRegardless()
                        window.level = .modalPanel // Use a higher level temporarily
                        
                        // Reset window level after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            window.level = .normal
                            window.makeKey() // Ensure window has focus
                        }
                    }
                }
            }
        }
    }
    
    private func createJSONTree() {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return
        }
        jsonRoot = JSONTreeNode(value: json)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
    
    private func findNode(path: String, in root: JSONTreeNode?) -> JSONTreeNode? {
        guard let root = root else { return nil }
        
        if root.jsonPath() == path {
            return root
        }
        
        guard let children = root.children else { return nil }
        for child in children {
            if let found = findNode(path: path, in: child) {
                return found
            }
        }
        return nil
    }
}

// WebView for rendering HTML content
struct WebView: NSViewRepresentable {
    let htmlString: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if let data = htmlString.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributedString)
        } else {
            textView.string = htmlString
        }
    }
}

// --- URL List Window ---
struct URLListView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.colorScheme) var colorScheme

    // Helper to show minutes ago, rounded to the nearest minute
    func minutesAgoString(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes <= 0 {
            return "just now"
        } else if minutes == 1 {
            return "1 minute ago"
        } else {
            return "\(minutes) minutes ago"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Copied URLs")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    clipboardManager.closeURLListWindow()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding([.top, .horizontal])
            
            Divider()
            
            if clipboardManager.copiedURLs.isEmpty {
                Spacer()
                Text("No URLs copied yet.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List(clipboardManager.copiedURLs) { urlItem in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(urlItem.url)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(minutesAgoString(from: urlItem.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            clipboardManager.deleteURL(urlItem)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(colorScheme == .dark ? Color.black : Color(NSColor.windowBackgroundColor))
    }
} 