import SwiftUI
import AppKit

struct JSONTreeView: NSViewRepresentable {
    @Binding var rootNode: JSONTreeNode
    @Binding var selectedPath: String
    @EnvironmentObject var contentManager: WindowContentManager
    let onCoordinatorCreated: (Coordinator) -> Void
    
    init(rootNode: Binding<JSONTreeNode>, selectedPath: Binding<String>, onCoordinatorCreated: @escaping (Coordinator) -> Void) {
        _rootNode = rootNode
        _selectedPath = selectedPath
        self.onCoordinatorCreated = onCoordinatorCreated
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(rootNode: $rootNode, selectedPath: $selectedPath, contentManager: contentManager)
        onCoordinatorCreated(coordinator)
        return coordinator
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()
        
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        
        outlineView.headerView = nil
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("JSONTree"))
        column.title = "JSON Tree"
        outlineView.addTableColumn(column)
        
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        context.coordinator.outlineView = outlineView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        
        if context.coordinator.outlineView == nil {
            context.coordinator.outlineView = outlineView
        }
        
        outlineView.reloadData()
    }
    
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        @Binding var rootNode: JSONTreeNode
        @Binding var selectedPath: String
        weak var outlineView: NSOutlineView?
        let contentManager: WindowContentManager
        
        init(rootNode: Binding<JSONTreeNode>, selectedPath: Binding<String>, contentManager: WindowContentManager) {
            _rootNode = rootNode
            _selectedPath = selectedPath
            self.contentManager = contentManager
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
            return !(node.children?.isEmpty ?? true)
        }
        
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? JSONTreeNode else { return nil }
            
            let text = NSTextField()
            text.isEditable = false
            text.isBordered = false
            text.drawsBackground = false
            text.stringValue = node.displayString
            
            return text
        }
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }
            let selectedRow = outlineView.selectedRow
            guard selectedRow >= 0,
                  let node = outlineView.item(atRow: selectedRow) as? JSONTreeNode else { return }
            selectedPath = node.jsonPath()
        }
        
        @objc func handleDoubleClick(_ sender: Any?) {
            guard let outlineView = sender as? NSOutlineView else { return }
            let clickedRow = outlineView.clickedRow
            guard clickedRow >= 0,
                  let node = outlineView.item(atRow: clickedRow) as? JSONTreeNode else { return }
            contentManager.broadcastJsonPath(node.jsonPath())
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
                var parent: JSONTreeNode? = node
                while parent != nil {
                    outlineView.expandItem(parent)
                    parent = parent?.parent
                }
                
                let row = outlineView.row(forItem: node)
                if row >= 0 {
                    outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(row)
                }
            }
        }
    }
} 