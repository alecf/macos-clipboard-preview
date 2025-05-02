import SwiftUI
import AppKit

struct JSONTreeView: NSViewRepresentable {
    @Binding var rootNode: JSONTreeNode
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()
        
        // Configure outline view
        outlineView.style = .plain // Changed from .sourceList for better appearance
        outlineView.rowSizeStyle = .default
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("JSONColumn"))
        column.title = "JSON"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        // Remove header and make column fill width
        outlineView.headerView = nil
        column.width = 1000 // Make column very wide
        
        // Set up scroll view
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        // Make outline view fill scroll view
        outlineView.frame = scrollView.bounds
        outlineView.autoresizingMask = [.width, .height]
        
        // Expand all items
        outlineView.expandItem(nil, expandChildren: true)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        outlineView.reloadData()
        // Re-expand all items after reload
        outlineView.expandItem(nil, expandChildren: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(rootNode: $rootNode)
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        @Binding var rootNode: JSONTreeNode
        
        init(rootNode: Binding<JSONTreeNode>) {
            _rootNode = rootNode
        }
        
        // Data source methods
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil {
                return 1
            }
            guard let node = item as? JSONTreeNode else { return 0 }
            return node.children?.count ?? 0
        }
        
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil {
                return rootNode
            }
            guard let node = item as? JSONTreeNode,
                  let children = node.children else { return JSONTreeNode(value: "") }
            return children[index]
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? JSONTreeNode else { return false }
            return !node.isLeaf
        }
        
        // Delegate methods
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? JSONTreeNode else { return nil }
            
            let stackView = NSStackView()
            stackView.orientation = .horizontal
            stackView.spacing = 0
            
            // Split the display string into key and value parts
            let parts = node.displayString.split(separator: "\u{001F}", omittingEmptySubsequences: false)
            
            if parts.count > 1 {
                // Has key part
                let keyField = NSTextField()
                keyField.isEditable = false
                keyField.isBordered = false
                keyField.drawsBackground = false
                keyField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                keyField.stringValue = String(parts[1])  // The key part
                keyField.textColor = .secondaryLabelColor
                stackView.addArrangedSubview(keyField)
                
                // Add the colon and space
                let colonField = NSTextField()
                colonField.isEditable = false
                colonField.isBordered = false
                colonField.drawsBackground = false
                colonField.stringValue = ": "
                colonField.textColor = .labelColor
                stackView.addArrangedSubview(colonField)
                
                // Value part
                let valueField = NSTextField()
                valueField.isEditable = false
                valueField.isBordered = false
                valueField.drawsBackground = false
                valueField.stringValue = String(parts[2])
                valueField.maximumNumberOfLines = 0
                valueField.lineBreakMode = .byWordWrapping
                
                // Style based on content type
                if node.isLeaf {
                    if node.value is String {
                        valueField.textColor = .systemGreen
                    } else if node.value is NSNumber {
                        valueField.textColor = .systemBlue
                    } else if node.value is NSNull {
                        valueField.textColor = .systemGray
                    } else {
                        valueField.textColor = .labelColor
                    }
                } else {
                    // Use normal font and bright color for all collection types
                    valueField.font = .systemFont(ofSize: NSFont.systemFontSize)
                    valueField.textColor = .labelColor
                }
                
                stackView.addArrangedSubview(valueField)
            } else {
                // No key part (root value)
                let valueField = NSTextField()
                valueField.isEditable = false
                valueField.isBordered = false
                valueField.drawsBackground = false
                valueField.stringValue = node.displayString
                valueField.maximumNumberOfLines = 0
                valueField.lineBreakMode = .byWordWrapping
                valueField.font = .systemFont(ofSize: NSFont.systemFontSize)
                valueField.textColor = .labelColor
                
                stackView.addArrangedSubview(valueField)
            }
            
            return stackView
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
            guard let node = item as? JSONTreeNode else { return false }
            node.isExpanded = true
            return true
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
            guard let node = item as? JSONTreeNode else { return false }
            node.isExpanded = false
            return true
        }
    }
} 