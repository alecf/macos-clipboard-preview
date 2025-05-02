import SwiftUI
import AppKit

struct JSONTreeView: NSViewRepresentable {
    @Binding var rootNode: JSONTreeNode
    @Binding var selectedPath: String
    @EnvironmentObject var contentManager: WindowContentManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    let onCoordinatorCreated: (Coordinator) -> Void
    
    init(rootNode: Binding<JSONTreeNode>, selectedPath: Binding<String>, onCoordinatorCreated: @escaping (Coordinator) -> Void) {
        _rootNode = rootNode
        _selectedPath = selectedPath
        self.onCoordinatorCreated = onCoordinatorCreated
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(rootNode: $rootNode, selectedPath: $selectedPath, clipboardManager: clipboardManager)
        onCoordinatorCreated(coordinator)
        return coordinator
    }
    
    func makeNSView(context: Context) -> NSScrollView {
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
        
        // Set up double-click handling
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        outlineView.action = nil // Ensure single clicks don't interfere
        
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
        
        // Store reference and expand items
        context.coordinator.outlineView = outlineView
        outlineView.expandItem(nil, expandChildren: true)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        
        if context.coordinator.outlineView == nil {
            context.coordinator.outlineView = outlineView
        }
        
        outlineView.reloadData()
        // Re-expand all items after reload
        outlineView.expandItem(nil, expandChildren: true)
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        @Binding var rootNode: JSONTreeNode
        @Binding var selectedPath: String
        weak var outlineView: NSOutlineView?
        let clipboardManager: ClipboardManager
        private var selectedRow: Int = -1
        
        init(rootNode: Binding<JSONTreeNode>, selectedPath: Binding<String>, clipboardManager: ClipboardManager) {
            _rootNode = rootNode
            _selectedPath = selectedPath
            self.clipboardManager = clipboardManager
            super.init()
        }
        
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
                  let children = node.children else { return JSONTreeNode(value: NSNull()) }
            return children[index]
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? JSONTreeNode else { return false }
            return !node.isLeaf
        }
        
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
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }
            selectedRow = outlineView.selectedRow
            
            if let item = outlineView.item(atRow: selectedRow) as? JSONTreeNode {
                selectedPath = item.jsonPath()
            } else {
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
        
        @objc func handleDoubleClick(_ sender: Any?) {
            guard let outlineView = outlineView,
                  outlineView.clickedRow >= 0,
                  let node = outlineView.item(atRow: outlineView.clickedRow) as? JSONTreeNode else {
                return
            }
            
            let clickedRow = outlineView.clickedRow
            
            // Update selection
            outlineView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            selectedRow = clickedRow
            
            // Broadcast the path
            let path = node.jsonPath()
            selectedPath = path
            clipboardManager.broadcastJsonPath(path)
            
            // Emphasize the selection
            if let rowView = outlineView.rowView(atRow: clickedRow, makeIfNecessary: true) {
                rowView.isSelected = true
                rowView.isEmphasized = true
            }
        }
        
        func selectItemWithPath(_ path: String, in outlineView: NSOutlineView) {
            func findNode(path: String, in node: JSONTreeNode) -> JSONTreeNode? {
                if node.jsonPath() == path {
                    return node
                }
                guard let children = node.children else { return nil }
                for child in children {
                    if let found = findNode(path: path, in: child) {
                        return found
                    }
                }
                return nil
            }
            
            if let node = findNode(path: path, in: rootNode) {
                // First expand all parent nodes
                var parent: JSONTreeNode? = node
                while parent != nil {
                    outlineView.expandItem(parent)
                    parent = parent?.parent
                }
                
                // Find and select the row
                let row = outlineView.row(forItem: node)
                if row >= 0 {
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(row)
                    
                    // Update selected row and emphasize it
                    selectedRow = row
                    if let rowView = outlineView.rowView(atRow: row, makeIfNecessary: true) {
                        rowView.isSelected = true
                        rowView.isEmphasized = true
                    }
                }
            }
        }
    }
} 