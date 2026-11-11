//
//  IFSkeinItem.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//  Translated from Objective-C in November 2026. The interface is still IFSkeinItem.h, and the
//  pasteboard type is defined in IFSkeinConstants.m.
//

import Cocoa

// MARK: - "Skein Item"
@objc @implementation extension IFSkeinItem {

    private var _children: NSMutableArray
    private var differencesHash: UInt                   // Hash to work out if differences need recalculating

    private var _command: String
    private var _ideal: String
    private var _actual: String
    private weak var _parent: IFSkeinItem?
    private var _isTestSubItem: Bool

    let uniqueId: UInt
    var skein: IFSkein?
    var diffCachedResult: IFDiffer
    var commandSizeDidChange: Bool
    var cachedCommandSize: NSSize

    // MARK: - Initialization
    init(skein: IFSkein?,
         command com: String?) {
        uniqueId        = IFUtility.generateID()
        _command        = IFSkeinItem.sanitizeCommand(com)
        _actual         = ""
        _ideal          = ""
        _isTestSubItem  = false
        self.skein      = skein

        _parent         = nil
        _children       = NSMutableArray()

        // Command size
        commandSizeDidChange = true
        cachedCommandSize    = .zero

        // Differences
        differencesHash  = 0
        diffCachedResult = IFDiffer()

        super.init()
    }

    // MARK: - NSCoding
    @objc(encodeWithCoder:)
    func encode(with encoder: NSCoder) {
        encoder.encode(_children,       forKey: "children")
        encoder.encode(_command,        forKey: "command")
        encoder.encode(_actual,         forKey: "result")
        encoder.encode(_ideal,          forKey: "ideal")
        encoder.encode(_isTestSubItem,  forKey: "isTestSubItem")
    }

    public required init?(coder decoder: NSCoder) {
        uniqueId            = IFUtility.generateID()

        // Anything missing is empty, as in a new item
        _children           = decoder.decodeObject(of: [NSMutableArray.self, IFSkeinItem.self], forKey: "children") as? NSMutableArray ?? NSMutableArray()
        _command            = decoder.decodeObject(of: NSString.self, forKey: "command") as String? ?? ""
        _actual             = decoder.decodeObject(of: NSString.self, forKey: "result") as String? ?? ""
        _ideal              = decoder.decodeObject(of: NSString.self, forKey: "ideal") as String? ?? ""
        _isTestSubItem      = decoder.decodeBool(forKey: "isTestSubItem")
        diffCachedResult    = IFDiffer()
        differencesHash     = 0
        commandSizeDidChange = true
        cachedCommandSize   = .zero
        skein               = nil
        _parent             = nil

        super.init()

        for case let child as IFSkeinItem in _children {
            child._parent = self
        }
    }

    class var supportsSecureCoding: Bool {
        return true
    }

    // MARK: - Class Helpers
    // Sanitize the command: ensure it contains no control characters and no trailing whitespace
    private static func sanitizeCommand(_ command: String?) -> String {
        guard let command else { return "" }

        // Replace all Unicode control characters (0x00-0x1f and 0x7f-0x9f) with spaces
        let components = (command as NSString).components(separatedBy: CharacterSet.controlCharacters)
        let joined = components.joined(separator: " ") as NSString

        // Remove trailing whitespace
        return joined.removingTrailingWhitespace
    }

    class func string(byRemovingPrompt string: String?) -> String {
        guard let string else { return "" }

        let lastCarriageReturnIndex = (string as NSString).lastIndex(of: "\n")
        if lastCarriageReturnIndex == NSNotFound {
            return string
        }
        return (string as NSString).substring(to: lastCarriageReturnIndex)
    }

    @objc(promptForString:)
    class func prompt(for string: String?) -> String {
        guard let string else { return "" }

        let lastCarriageReturnIndex = (string as NSString).lastIndex(of: "\n")
        if lastCarriageReturnIndex == NSNotFound {
            return ""
        }
        return (string as NSString).substring(from: lastCarriageReturnIndex + 1)
    }

    // MARK: - Access to Document
    private var document: IFProject? {
        // Look through all documents
        let docs = NSDocumentController.shared.documents
        for doc in docs {
            if let project = doc as? IFProject {
                // Look through all skeins in each document looking for our root item
                for case let skein as IFSkein in project.skeins {
                    if skein === self.skein {
                        return project
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Undo Manager
    private var undoManager: UndoManager? {
        return document?.undoManager
    }

    /// Where to send a message that undoes a change, or nil if there's no skein or undo manager. The undo manager
    /// records the message it's sent next, to send to the skein, so it isn't cast, as a cast asks it its class. Nor
    /// is the message looked up on AnyObject, which finds none for the undo manager, as the skein is the main
    /// actor's.
    private var undoTarget: IFSkein? {
        guard let skein, let undoManager else { return nil }
        return unsafeBitCast(undoManager.prepare(withInvocationTarget: skein) as AnyObject, to: IFSkein.self)
    }

    private func disableUndo() {
        undoManager?.disableUndoRegistration()
    }

    private func enableUndo() {
        undoManager?.enableUndoRegistration()
    }

    // MARK: - Properties

    var children: [IFSkeinItem] {
        return _children.copy() as! [IFSkeinItem]
    }

    var nonTestChildren: [IFSkeinItem]? {
        var item: IFSkeinItem = self
        while item.children.count > 0 {
            let child = item.children[0]
            if !child.isTestSubItem {
                return item.children
            }
            item = child
        }
        return nil
    }

    func child(withCommand com: String, isTestSubItem: Bool) -> IFSkeinItem? {
        for case let childItem as IFSkeinItem in _children {
            if (childItem._command as NSString).isEqual(to: com) {
                if childItem.isTestSubItem == isTestSubItem {
                    return childItem
                }
            }
        }

        return nil
    }

    @objc(rootItem)
    var root: IFSkeinItem {
        var item: IFSkeinItem = self
        while let parent = item.parent {
            item = parent
        }
        return item
    }

    func hasDescendant(_ child: IFSkeinItem?) -> Bool {
        var item = child
        while let current = item {
            if current === self {
                return true
            }
            item = current.parent
        }
        return false
    }

    // Calculate a hash based on the current state. We only redraw the report when the hash changes.
    var reportStateHash: UInt {
        var hash = UInt(bitPattern: (_ideal as NSString).hash)
        hash ^= UInt(bitPattern: (_actual as NSString).hash) &+ 1
        hash ^= UInt(bitPattern: (_command as NSString).hash) &+ 2

        return hash
    }

    // MARK: - Changing the Skein
    weak var parent: IFSkeinItem? {
        get {
            return _parent
        }
        set(newParent) {
            if _parent === newParent {
                return
            }

            undoTarget?.setParentOf(self, parent: _parent)
            _parent = newParent
            skein?.setLayoutDirty()
            skein?.setSkeinChanged()
            if newParent?.skein !== skein {
                // The knots below this one move with it
                setSkeinRecursively(newParent?.skein)
                skein?.setLayoutDirty()
                skein?.setSkeinChanged()
            }
        }
    }

    func removeFromParent() {
        if let parent = _parent {
            parent.remove(fromChildrenArray: self)
            undoTarget?.setParentOf(self, parent: _parent)
            skein?.setLayoutDirty()
            skein?.setSkeinChanged()
            _parent = nil
            setSkeinRecursively(nil)
        }
    }

    func remove(fromChildrenArray itemToRemove: IFSkeinItem) {
        undoTarget?.add(toChildrenArrayOf: self, itemToAdd: itemToRemove)
        _children.remove(itemToRemove)
        skein?.setLayoutDirty()
        skein?.setSkeinChanged()
    }

    func add(toChildrenArray itemToAdd: IFSkeinItem) {
        // Insert childItem into children alphabetically
        undoTarget?.remove(fromChildrenArrayOf: self, itemToRemove: itemToAdd)
        var index = 0
        while index < _children.count {
            if ((_children[index] as! IFSkeinItem)._command as NSString).compare(itemToAdd._command) == .orderedDescending {
                break
            }
            index += 1
        }
        _children.insert(itemToAdd,
                         at: index)
        skein?.setLayoutDirty()
        skein?.setSkeinChanged()
    }

    private func mergeWith(_ newItem: IFSkeinItem) {
        // Make a local copy of the children
        let localChildren = newItem.children

        // Merges this item with another
        for childItem in localChildren {
            let oldChild = child(withCommand: childItem._command, isTestSubItem: childItem.isTestSubItem)

            if let oldChild {
                oldChild.mergeWith(childItem)
            } else {
                addChild(childItem)
            }
        }
    }

    private func setSkeinRecursively(_ newSkein: IFSkein?) {
        skein = newSkein
        for case let child as IFSkeinItem in _children {
            child.setSkeinRecursively(newSkein)
        }
    }

    @discardableResult
    func addChild(_ childItem: IFSkeinItem) -> IFSkeinItem {
        // Is there an existing child with the same command?
        if let oldChild = child(withCommand: childItem._command, isTestSubItem: childItem.isTestSubItem) {
            // Merge because this child item already exists
            oldChild.mergeWith(childItem)

            let newActual   = (childItem._actual as NSString).length > 0 ? childItem._actual : oldChild._actual
            let newIdeal    = (childItem._ideal as NSString).length > 0  ? childItem._ideal  : oldChild._ideal
            let newTestNode = childItem.isTestSubItem

            // Copy any new state over to the existing item
            oldChild.actual         = newActual
            oldChild.ideal          = newIdeal
            oldChild.isTestSubItem  = newTestNode

            return oldChild
        }

        // Otherwise, just add the new item
        childItem.removeFromParent()
        childItem.parent = self
        childItem.setSkeinRecursively(skein)

        add(toChildrenArray: childItem)

        return childItem
    }

    // MARK: - Item Data

    var command: String! {
        get {
            return _command
        }
        set(newCommand) {
            let newCommand = IFSkeinItem.sanitizeCommand(newCommand)

            if (newCommand as NSString).isEqual(to: _command) {
                return
            }

            undoTarget?.setCommandOf(self, command: _command)

            commandSizeDidChange = true
            _command = newCommand
            skein?.setLayoutDirty()
            skein?.setSkeinChanged()
        }
    }

    var actual: String! {
        get {
            return _actual
        }
        set(newActual) {
            let newActual = newActual ?? ""

            if (newActual as NSString).isEqual(to: _actual) {
                return
            }

            undoTarget?.setActualOf(self, actual: _actual)
            _actual = newActual
            skein?.setLayoutDirty()
            skein?.setSkeinChanged()
        }
    }

    var ideal: String! {
        get {
            return _ideal
        }
        set(newIdeal) {
            let newIdeal = newIdeal ?? ""
            if (newIdeal as NSString).isEqual(to: _ideal) {
                return
            }

            undoTarget?.setIdealOf(self, ideal: _ideal)
            _ideal = newIdeal
            skein?.setLayoutDirty()
            skein?.setSkeinChanged()
        }
    }

    var isTestSubItem: Bool {
        get {
            return _isTestSubItem
        }
        set(newIsTestSubItem) {
            setIsTestSubItemWith(NSNumber(value: newIsTestSubItem))
        }
    }

    @objc(setIsTestSubItemWithNSNumber:)
    func setIsTestSubItemWith(_ newIsTestSubItem: NSNumber) {
        if _isTestSubItem == newIsTestSubItem.boolValue {
            return
        }

        undoTarget?.setIsTestSubItemWithNSNumberOf(self,
                                                   isTestSubItemWith: NSNumber(value: _isTestSubItem))
        _isTestSubItem = newIsTestSubItem.boolValue
        skein?.setLayoutDirty()
        skein?.setSkeinChanged()
    }

    // MARK: - Differences
    var differences: IFDiffer {
        let newHash = reportStateHash

        if (differencesHash == 0) || (differencesHash != newHash) {
            var localIdeal: String  = ideal ?? ""
            var localActual: String = actual ?? ""

            // Preprocess the strings to remove matching prompts and trim matching whitespace
            // Remove matching prompts
            let promptsMatch            = (IFSkeinItem.prompt(for: localActual) as NSString).isEqual(to: IFSkeinItem.prompt(for: _ideal))
            let idealHasStandardPrompt  = (localIdeal as NSString).ends(with: "\n>")
            let actualHasStandardPrompt = (localActual as NSString).ends(with: "\n>")
            let hasIdealOutput          = (localIdeal as NSString).length > 0
            let hasActualOutput         = (localActual as NSString).length > 0
            let canRemovePrompt         = promptsMatch || (!hasActualOutput && idealHasStandardPrompt) || (!hasIdealOutput && actualHasStandardPrompt)
            if canRemovePrompt {
                localIdeal  = IFSkeinItem.string(byRemovingPrompt: localIdeal)
                localActual = IFSkeinItem.string(byRemovingPrompt: localActual)
            }

            // Remove matching trailing whitespace
            let idealTrailingWhitespace  = (localIdeal as NSString).trailingWhitespace
            let actualTrailingWhitespace = (localActual as NSString).trailingWhitespace
            if (idealTrailingWhitespace as NSString).isEqual(to: actualTrailingWhitespace) || !hasIdealOutput || !hasActualOutput {
                localIdeal  = (localIdeal as NSString).removingTrailingWhitespace
                localActual = (localActual as NSString).removingTrailingWhitespace
            }

            // Remove matching leading whitespace
            let idealLeadingWhitespace  = (localIdeal as NSString).leadingWhitespace
            let actualLeadingWhitespace = (localActual as NSString).leadingWhitespace
            if (idealLeadingWhitespace as NSString).isEqual(to: actualLeadingWhitespace) || !hasIdealOutput || !hasActualOutput {
                localIdeal  = (localIdeal as NSString).removingLeadingWhitespace
                localActual = (localActual as NSString).removingLeadingWhitespace
            }

            diffCachedResult.diffIdeal(localIdeal,
                                       actual: localActual)
            differencesHash = newHash
        }
        return diffCachedResult
    }

    var hasDifferences: Bool {
        return differences.differences.count > 0
    }

    var hasIdeal: Bool {
        return (ideal != nil) && ((ideal as NSString).length > 0)
    }

    var hasBadge: Bool {
        return hasIdeal && hasDifferences
    }

    // = Composing and decomposing "Test me" style nodes into separate items =
    // MARK: - Composing and Decomposing "test me" Style Nodes
    private static func componentsSeparatedByBracketedSequentialNumbers(_ string: String) -> [String] {
        let string = string as NSString
        var results: [String] = []

        var commandIndexToFind = 1
        var searchRange = NSRange(location: 0, length: string.length)
        while true {
            let stringToFind = "[\(commandIndexToFind)]"
            let range = string.range(of: stringToFind,
                                     options: .literal,
                                     range: searchRange)
            if range.location == NSNotFound {
                break
            }

            let foundString = string.substring(with: NSRange(location: searchRange.location,
                                                             length: range.location - searchRange.location))
            results.append(foundString)

            // Move beyond the separator to remainder of string
            let rangeEnd = range.location + range.length
            searchRange = NSRange(location: rangeEnd, length: string.length - rangeEnd)

            // Look for next number
            commandIndexToFind += 1
        }

        if searchRange.length > 0 {
            // Add remainder of string as the final component of the results
            results.append(string.substring(with: searchRange))
        }

        return results
    }

    private static func commandForEntry(_ entry: String, index: Int) -> String {
        var command = (entry as NSString).trimmingWhitespace
        let returnIndex = (command as NSString).index(of: "\n")
        if returnIndex != NSNotFound {
            command = (command as NSString).substring(to: returnIndex)
        }
        return command
    }

    private static func outputForEntry(_ entry: String) -> String {
        let returnIndex = (entry as NSString).index(of: "\n")
        if returnIndex != NSNotFound {
            return (entry as NSString).substring(from: returnIndex+1)
        }
        return ""
    }

    func decomposeActual(_ actual: String) -> IFSkeinItem {
        return decomposeActual(actual, ideal: composedIdeal)
    }

    /// For any "test me" style commands, separate out the testing commands into separate "isTestSubItem" child nodes
    private func decomposeActual(_ actual: String, ideal: String) -> IFSkeinItem {
        if !IFSkeinItem.isTestCommand(_command) {
            // This not a "test " command.
            self.actual = actual
            self.ideal = ideal
            return self
        }

        let actualResults = IFSkeinItem.componentsSeparatedByBracketedSequentialNumbers(actual)
        let idealResults  = IFSkeinItem.componentsSeparatedByBracketedSequentialNumbers(ideal)
        disableUndo()
        if actualResults.count > 0 {
            // Set the first entry text (usually something like "(Testing)\n\n>")
            self.actual = actualResults[0]
            if idealResults.count > 0 {
                self.ideal = idealResults[0]
            }
        }

        if actualResults.count > 1 {
            // Remove but remember the 'real' children of the node ie. skipping over any intermediate test nodes
            let localChildren = nonTestChildren ?? []

            var parentItem: IFSkeinItem = self
            var mergedItem: IFSkeinItem = self

            // Go through remaining entries, inserting test child items as we go
            for index in 1..<actualResults.count {
                let actualEntry = actualResults[index]
                let actualCommand = IFSkeinItem.commandForEntry(actualEntry, index: index)
                let actualOutput  = IFSkeinItem.outputForEntry(actualEntry)
                //NSString* idealCommand = @"";
                var idealOutput = ""
                if idealResults.count > index {
                    let idealEntry = idealResults[index]
                    //idealCommand = [IFSkeinItem commandForEntry: idealEntry];
                    idealOutput  = IFSkeinItem.outputForEntry(idealEntry)
                }

                let newItem = IFSkeinItem(skein: skein, command: actualCommand)
                newItem._actual = actualOutput
                newItem._ideal  = idealOutput
                newItem._parent = parentItem
                newItem._isTestSubItem = true

                mergedItem = parentItem.addChild(newItem)

                // If we have branched off into a new node. We remove any old nodes remaining.
                if mergedItem === newItem {
                    for itemToRemove in parentItem.children {
                        if itemToRemove !== newItem {
                            itemToRemove.removeFromParent()
                        }
                    }
                }

                parentItem = mergedItem
            }

            // Remove children from old location and add them in the new location (if location has changed)
            if localChildren.count > 0 {
                if localChildren[0].parent !== mergedItem {
                    for child in localChildren {
                        child.removeFromParent()
                    }

                    mergedItem._children = NSMutableArray(array: localChildren)
                    for case let item as IFSkeinItem in mergedItem._children {
                        item.parent = mergedItem
                    }
                    mergedItem.setSkeinRecursively(skein)
                }
            }

            enableUndo()
            return mergedItem
        }
        enableUndo()
        return self
    }

    class func isTestCommand(_ command: String) -> Bool {
        return (command as NSString).starts(withCaseInsensitive: "test ")
    }

    @objc(findItemWithNodeId:)
    func find(withNodeId skeinNodeId: UInt) -> IFSkeinItem? {
        if uniqueId == skeinNodeId {
            return self
        }

        for child in children {
            if let foundItem = child.find(withNodeId: skeinNodeId) {
                return foundItem
            }
        }
        return nil
    }

    var decompose: IFSkeinItem {
        return decomposeActual(_actual, ideal: _ideal)
    }

    var composedActual: String {
        // Find the range of items to compose (self -> leafItem)
        var leafItem: IFSkeinItem = self
        var commandTotal = 1
        while leafItem.children.count == 1 {
            let child = leafItem.children[0]
            if !child.isTestSubItem {
                break
            }

            leafItem = child
            commandTotal += 1
        }

        // Combine the items
        let combinedActual = NSMutableString(string: _actual)
        var loopItem: IFSkeinItem = self
        for commandIndex in 1..<commandTotal {
            loopItem = loopItem.children[0]
            combinedActual.append("[\(commandIndex)] \(loopItem._command)\n\(loopItem._actual)")
        }
        return combinedActual as String
    }

    var composedIdeal: String {
        // Find the range of items to compose (self -> leafItem)
        var leafItem: IFSkeinItem = self
        var commandTotal = 1
        while leafItem.children.count == 1 {
            let child = leafItem.children[0]
            if !child.isTestSubItem {
                break
            }

            leafItem = child
            commandTotal += 1
        }

        // Combine the items
        let combinedIdeal = NSMutableString(string: _ideal)
        var loopItem: IFSkeinItem = self
        for commandIndex in 1..<commandTotal {
            loopItem = loopItem.children[0]
            combinedIdeal.append("[\(commandIndex)] \(loopItem._command)\n\(loopItem._ideal)")
        }
        return combinedIdeal as String
    }

    // MARK: - Command Size Cache
    func forceCommandSizeChangeRecursively() {
        commandSizeDidChange = true
        for case let child as IFSkeinItem in _children {
            child.forceCommandSizeChangeRecursively()
        }
    }

    // MARK: - Debugging
    private func printDEBUG() {
        NSLog("Item(%lu) '%@'\n", uniqueId, _command)
        var childCount: Int32 = 0
        for case let child as IFSkeinItem in _children {
            NSLog("Item(%lu) child #%d:\n", uniqueId, childCount)
            child.printDEBUG()
            childCount += 1
        }
    }

    // MARK: - NSPasteboardWriting implementation

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type.rawValue == IFSkeinItemPboardType {
            return try? NSKeyedArchiver.archivedData(withRootObject: self,
                                                     requiringSecureCoding: true)
        }
        return nil
    }

    @objc(writableTypesForPasteboard:)
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        if pasteboard.name == .drag {
            return [NSPasteboard.PasteboardType(IFSkeinItemPboardType)]
        }
        return []
    }
}
