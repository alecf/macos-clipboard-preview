import SwiftUI

@main
struct ClipboardPreviewApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        
        MenuBarExtra {
            VStack {
                Text("Clipboard Preview")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                
                Divider()
                
                if clipboardManager.windowItems.isEmpty {
                    Text("No active windows")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 5)
                } else {
                    ForEach(clipboardManager.windowItems) { item in
                        Button(action: { clipboardManager.showWindow(item) }) {
                            Text(item.previewTitle)
                                .lineLimit(1)
                        }
                    }
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .frame(minWidth: 200)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
    }
} 