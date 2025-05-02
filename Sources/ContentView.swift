import SwiftUI
import Down

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
                        contentType: contentManager.contentType)
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
    
    class ViewState: ObservableObject {
        @Published var coordinator: JSONTreeView.Coordinator?
        
        func setCoordinator(_ newCoordinator: JSONTreeView.Coordinator) {
            print("Setting new coordinator") // Debug print
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
            if contentType == .json {
                createJSONTree()
            }
        }
        .onChange(of: clipboardManager.broadcastedJsonPath) { oldValue, newValue in
            print("Window received broadcast: \(String(describing: newValue))")
            if contentType == .json, // Only handle if we're showing JSON
               let path = newValue,
               let currentCoordinator = viewState.coordinator,
               let outlineView = currentCoordinator.outlineView {
                selectedPath = path
                currentCoordinator.selectItemWithPath(path, in: outlineView)
            }
        }
    }
    
    private func createJSONTree() {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            print("Failed to create JSON tree") // Debug print
            return
        }
        jsonRoot = JSONTreeNode(value: json)
        print("JSON tree created") // Debug print
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