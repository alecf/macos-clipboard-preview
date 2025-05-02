import SwiftUI
import Down

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    let windowItem: WindowItem
    @State private var selectedTab: Int
    
    init(windowItem: WindowItem) {
        self.windowItem = windowItem
        _selectedTab = State(initialValue: windowItem.selectedTab)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Preview Tab
            PreviewTab(content: clipboardManager.currentContent,
                      contentType: clipboardManager.contentType)
                .tabItem {
                    Label("Preview", systemImage: "eye")
                }
                .tag(0)
            
            // Formatted Tab
            FormattedTab(content: clipboardManager.formattedContent,
                        contentType: clipboardManager.contentType)
                .tabItem {
                    Label("Formatted", systemImage: "wand.and.stars")
                }
                .tag(1)
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding()
        .onAppear {
            // Set initial tab based on content only for new windows
            if selectedTab == 0 && clipboardManager.hasFormattedContent {
                selectedTab = 1
            }
        }
        .onChange(of: clipboardManager.currentContent) { _ in
            // Reset to preview tab when new content arrives only if this window matches the current content
            if windowItem.content == clipboardManager.currentContent {
                selectedTab = 0
            }
        }
        .onChange(of: clipboardManager.hasFormattedContent) { success in
            // Switch to formatted tab only if this window matches the current content
            if success && windowItem.content == clipboardManager.currentContent {
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Update the window item's selected tab
            if let index = clipboardManager.windowItems.firstIndex(where: { $0.id == windowItem.id }) {
                clipboardManager.windowItems[index].selectedTab = newTab
            }
        }
    }
}

struct PreviewTab: View {
    let content: String
    let contentType: ClipboardManager.ContentType
    
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
    let contentType: ClipboardManager.ContentType
    @State private var jsonRoot: JSONTreeNode?
    @State private var selectedPath: String = "$"
    @EnvironmentObject var clipboardManager: ClipboardManager
    @StateObject private var viewState = ViewState()
    
    class ViewState: ObservableObject {
        @Published var coordinator: JSONTreeView.Coordinator?
        
        func setCoordinator(_ newCoordinator: JSONTreeView.Coordinator) {
            print("ViewState: Setting coordinator \(ObjectIdentifier(newCoordinator))")
            if let existing = coordinator {
                print("ViewState: Replacing existing coordinator \(ObjectIdentifier(existing))")
            }
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
                    print("JSONTreeView created with coordinator: \(ObjectIdentifier(newCoordinator))")
                    viewState.setCoordinator(newCoordinator)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .onAppear {
            print("FormattedTab appeared")
            if contentType == .json {
                createJSONTree()
            }
        }
        .onChange(of: clipboardManager.broadcastedJsonPath) { newPath in
            print("Received broadcast in FormattedTab: \(String(describing: newPath))")
            if let path = newPath {
                print("Have path: \(path)")
                if let currentCoordinator = viewState.coordinator {
                    print("Have coordinator from ViewState: \(ObjectIdentifier(currentCoordinator))")
                    if let outlineView = currentCoordinator.outlineView {
                        print("Have outline view: \(ObjectIdentifier(outlineView))")
                        selectedPath = path
                        currentCoordinator.selectItemWithPath(path, in: outlineView)
                    } else {
                        print("Coordinator has no outline view")
                    }
                } else {
                    print("No coordinator available in ViewState")
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