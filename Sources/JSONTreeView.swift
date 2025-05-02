import SwiftUI
import AppKit

struct JSONTreeView: NSViewRepresentable {
    @Binding var rootNode: JSONTreeNode
    @Binding var selectedPath: String
    @EnvironmentObject var clipboardManager: ClipboardManager
    var onCoordinatorCreated: ((Coordinator) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        print("makeNSView called")
        // Store coordinator in parent if requested
        onCoordinatorCreated?(context.coordinator)
        
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()
        
        // Configure outline view
        outlineView.style = .plain
        outlineView.rowSizeStyle = .default
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        outlineView.selectionHighlightStyle = .regular
        outlineView.allowsEmptySelection = true
        outlineView.focusRingType = .none
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("JSONColumn"))
        column.title = "JSON"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        // Remove header and make column fill width
        outlineView.headerView = nil
        column.width = 1000
        
        // Set up scroll view
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        // Make outline view fill scroll view
        outlineView.frame = scrollView.bounds
        outlineView.autoresizingMask = [.width, .height]
        
        // Store the outline view in coordinator
        print("Setting outline view in coordinator")
        context.coordinator.outlineView = outlineView
        
        // Expand all items
        outlineView.expandItem(nil, expandChildren: true)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        print("updateNSView called")
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        outlineView.reloadData()
        // Re-expand all items after reload
        outlineView.expandItem(nil, expandChildren: true)
        
        // Ensure coordinator still has reference
        if context.coordinator.outlineView == nil {
            print("Restoring outline view reference in coordinator")
            context.coordinator.outlineView = outlineView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        print("makeCoordinator called")
        let coordinator = Coordinator(rootNode: $rootNode, selectedPath: $selectedPath, clipboardManager: clipboardManager)
        print("Created coordinator: \(ObjectIdentifier(coordinator))")
        return coordinator
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        @Binding var rootNode: JSONTreeNode
        @Binding var selectedPath: String
        private var selectedRow: Int = -1
        private let clipboardManager: ClipboardManager
        weak var outlineView: NSOutlineView? {
            didSet {
                if let view = outlineView {
                    print("Outline view set in coordinator \(ObjectIdentifier(self)): \(ObjectIdentifier(view))")
                } else {
                    print("Outline view cleared in coordinator \(ObjectIdentifier(self))")
                }
            }
        }
        
        init(rootNode: Binding<JSONTreeNode>, selectedPath: Binding<String>, clipboardManager: ClipboardManager) {
            print("Initializing coordinator")
            _rootNode = rootNode
            _selectedPath = selectedPath
            self.clipboardManager = clipboardManager
            super.init()
        }
        
        deinit {
            print("Coordinator \(ObjectIdentifier(self)) being deallocated")
        }
        
        @objc func handleDoubleClick(_ sender: Any?) {
            print("Double click detected")
            guard let outlineView = sender as? NSOutlineView else {
                print("Sender is not an NSOutlineView")
                return
            }
            let clickedRow = outlineView.clickedRow
            print("Clicked row: \(clickedRow)")
            if clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? JSONTreeNode {
                let path = item.jsonPath()
                print("Broadcasting path: \(path)")
                clipboardManager.broadcastJsonPath(path)
            }
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
        
        // Selection handling
        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }
            selectedRow = outlineView.selectedRow
            print("Selection changed to row: \(selectedRow)")
            
            // Update selected path
            if let item = outlineView.item(atRow: selectedRow) as? JSONTreeNode {
                let path = item.jsonPath()
                print("Updating selected path to: \(path)")
                selectedPath = path
            } else {
                print("Setting default path: $")
                selectedPath = "$"
            }
        }
        
        func outlineViewSelectionIsChanging(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }
            outlineView.enumerateAvailableRowViews { rowView, _ in
                rowView.isEmphasized = true
            }
        }
        
        func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
            if row == selectedRow {
                rowView.isSelected = true
                rowView.isEmphasized = true
            }
        }
        
        // Handle selection from broadcast
        func selectItemWithPath(_ path: String, in outlineView: NSOutlineView) {
            print("Selecting item with path: \(path)")
            
            // Helper function to find a node with a specific path
            func findNode(matching path: String, in node: JSONTreeNode) -> JSONTreeNode? {
                print("Checking node with path: \(node.jsonPath())")
                if node.jsonPath() == path {
                    return node
                }
                if let children = node.children {
                    for child in children {
                        if let match = findNode(matching: path, in: child) {
                            return match
                        }
                    }
                }
                return nil
            }
            
            if let node = findNode(matching: path, in: rootNode) {
                print("Found matching node")
                let row = outlineView.row(forItem: node)
                print("Node is at row: \(row)")
                if row >= 0 {
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    print("Selected row \(row)")
                }
            } else {
                print("No matching node found for path: \(path)")
            }
        }
    }
} 