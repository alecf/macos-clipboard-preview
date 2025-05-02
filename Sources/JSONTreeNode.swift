import Foundation

class JSONTreeNode: Identifiable {
    let id = UUID()
    let key: String?
    let value: Any
    var children: [JSONTreeNode]?
    var isExpanded: Bool
    weak var parent: JSONTreeNode?
    
    init(key: String? = nil, value: Any, isExpanded: Bool = true, parent: JSONTreeNode? = nil) {
        self.key = key
        self.value = value
        self.isExpanded = isExpanded
        self.parent = parent
        
        if let array = value as? [Any] {
            self.children = array.enumerated().map { (index, value) in
                JSONTreeNode(key: "[\(index)]", value: value, isExpanded: true, parent: self)
            }
        } else if let dict = value as? [String: Any] {
            self.children = dict.map { (key, value) in
                JSONTreeNode(key: key, value: value, isExpanded: true, parent: self)
            }.sorted { $0.key ?? "" < $1.key ?? "" }
        }
    }
    
    var isLeaf: Bool {
        return children == nil || children?.isEmpty == true
    }
    
    var displayString: String {
        if let key = key {
            return "\u{001F}\(key)\u{001F}\(stringValue)"  // Removed the colon here since it's added in the view
        }
        return stringValue
    }
    
    private var stringValue: String {
        if isLeaf {
            if value is NSNull {
                return "null"
            } else if let bool = value as? Bool {
                return bool ? "true" : "false"
            } else if let str = value as? String {
                return "\"\(str)\""  // Add quotes around strings
            } else if value is NSNumber {
                return "\(value)"
            }
        }
        
        if value is [Any] {
            return "Array[\(children?.count ?? 0)]"
        } else if let dict = value as? [String: Any] {
            let keyCount = dict.count
            if keyCount == 0 {
                return "{} (no keys)"
            } else {
                return "(\(keyCount) key\(keyCount == 1 ? "" : "s"))"
            }
        }
        
        return "\(value)"
    }
    
    // Calculate JSONPath for this node
    func jsonPath() -> String {
        var path = [String]()
        var current: JSONTreeNode? = self
        
        while let node = current {
            if let key = node.key {
                // If key starts with [, it's an array index
                if key.hasPrefix("[") {
                    path.insert(key, at: 0)
                } else {
                    path.insert("." + key, at: 0)
                }
            }
            current = node.parent
        }
        
        // If path is empty, return root indicator
        if path.isEmpty {
            return "$"
        }
        
        // Join all parts and prepend with root indicator
        return "$" + path.joined()
    }
} 