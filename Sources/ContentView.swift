import SwiftUI
import Down

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedTab: Int = 0
    
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
        .onChange(of: clipboardManager.hasFormattedContent) { success in
            if success {
                selectedTab = 1
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Formatted Content")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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