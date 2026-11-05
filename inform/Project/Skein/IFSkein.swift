//
//  IFSkein.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//  Translated from Objective-C in November 2026. The interface is still IFSkein.h, and the
//  notification names and keys are defined in IFSkeinConstants.m.
//

import Cocoa

// MARK: - "Skein"
@objc @implementation extension IFSkein {

    private var _rootItem: IFSkeinItem
    private var _previousCommands: NSMutableArray

    var rootItem: IFSkeinItem {
        return _rootItem
    }
    var activeItem: IFSkeinItem?
    var winningItem: IFSkeinItem?
    var skeinChanged: Bool
    var previousCommands: NSMutableArray {
        return _previousCommands
    }
    var draggingItem: IFSkeinItem?
    var draggingSourceNeedsUpdating: Bool

    private weak var project: IFProject?
    private var currentOutput: NSMutableString
    private var dirtyLayout: Bool       // Does the layout need to be redone?

    // MARK: - Initialize
    init(project theProject: IFProject?) {
        project                     = theProject
        _rootItem                   = IFSkeinItem(skein: nil, command: "- start -")
        activeItem                  = nil
        winningItem                 = nil
        draggingSourceNeedsUpdating = false
        draggingItem                = nil
        currentOutput               = NSMutableString()
        _previousCommands           = NSMutableArray()
        dirtyLayout                 = true // Does the skein need laying out?
        skeinChanged                = true // Has the skein actually changed recently?

        super.init()

        // Swift can only give the root item this skein once the skein is initialised
        _rootItem.skein = self

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didUndo(_:)),
                                               name: .NSUndoManagerDidUndoChange,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didRedo(_:)),
                                               name: .NSUndoManagerDidRedoChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications
    func setLayoutDirty() {
        dirtyLayout = true
    }

    func setSkeinChanged() {
        skeinChanged = true
    }

    @objc(postSkeinChangedWithAnimate:keepActiveVisible:)
    func postChanged(withAnimate animate: Bool,
                     keepActiveVisible: Bool) {
        dirtyLayout = false
        let userDictionary: [String: Any] = [ IFSkeinChangedAnimateKey: animate,
                                              IFSkeinKeepActiveVisibleKey: keepActiveVisible ]

        NotificationCenter.default.post(name: .IFSkeinChanged,
                                        object: self,
                                        userInfo: userDictionary)
    }

    // = Output receiver =
    // MARK: - Interpreter Support
    func inputCommand(_ command: String) {
        // Remember the command in a list of commands already played
        _previousCommands.insert(command, at: 0)

        // Disable undo
        project?.undoManager?.disableUndoRegistration()

        // Track whether the skein actually changes due to adding this command
        skeinChanged = false

        // Create a new item
        let newItem = IFSkeinItem(skein: self, command: command)

        // Merge the item into the skein
        let mergedItem = activeItem?.addChild(newItem)

        precondition((activeItem == nil) || (activeItem?.skein != nil), "Active item has no skein #1")

        // Move the 'active' item
        activeItem = mergedItem

        precondition((activeItem == nil) || (activeItem?.skein != nil), "Active item has no skein #2")

        // Create a buffer for any new output
        currentOutput = NSMutableString()

        // Enable undo, but clear all undo skein commands from the stack. Mark the document as changed if required.
        project?.undoManager?.enableUndoRegistration()
        project?.undoManager?.removeAllActions(withTarget: self)
        if skeinChanged {
            project?.updateChangeCount(.changeDone)
        }

        // Notify anyone who's watching that we've updated
        postChanged(withAnimate: false,
                    keepActiveVisible: false)
    }

    func inputCharacter(_ character: String) {
        // We convert characters to their ZSCII equivalent (codes 129-144 and 252-254 for mouse clicks)
        var character = character
        var key: unichar = 0

        switch Int((character as NSString).character(at: 0)) {
        // Arrow keys
        case NSUpArrowFunctionKey:      key = 129
        case NSDownArrowFunctionKey:    key = 130
        case NSLeftArrowFunctionKey:    key = 131
        case NSRightArrowFunctionKey:   key = 132

        // Delete/return
        case NSDeleteFunctionKey:       key = 8

        // Function keys
        case NSF1FunctionKey:           key = 133
        case NSF2FunctionKey:           key = 134
        case NSF3FunctionKey:           key = 135
        case NSF4FunctionKey:           key = 136
        case NSF5FunctionKey:           key = 137
        case NSF6FunctionKey:           key = 138
        case NSF7FunctionKey:           key = 139
        case NSF8FunctionKey:           key = 140
        case NSF9FunctionKey:           key = 141
        case NSF10FunctionKey:          key = 142
        case NSF11FunctionKey:          key = 143
        case NSF12FunctionKey:          key = 144

        // Mouse buttons (we use fake function keys for this)
        case NSF33FunctionKey:          key = 252
        case NSF34FunctionKey:          key = 254
        case NSF35FunctionKey:          key = 253

        default:                        break
        }

        if key != 0 {
            let newCharacter = NSMutableString(string: character)

            newCharacter.replaceCharacters(in: NSRange(location: 0, length: 1),
                                           with: NSString(characters: &key,
                                                          length: 1) as String)
            character = newCharacter as String
        }

        inputCommand(character)
    }

    func outputText(_ outputText: String) {
        // Append this text to the current outout
        currentOutput.append(outputText)
    }

    func waitingForInput() {
        // Send the current output to the active item
        if currentOutput.length > 0 {
            // Disable undo
            project?.undoManager?.disableUndoRegistration()

            // Track whether the skein actually changes due to adding the latest output
            skeinChanged = false

            activeItem = activeItem?.decomposeActual(currentOutput as String)

            // Enable undo, but clear all undo commands from the stack.
            project?.undoManager?.enableUndoRegistration()
            project?.undoManager?.removeAllActions(withTarget: self)

            if skeinChanged {
                // Mark the document as changed
                project?.updateChangeCount(.changeDone)
            }

            postChanged(withAnimate: false,
                        keepActiveVisible: true)

            currentOutput = NSMutableString()
        }
    }

    func interpreterRestart() {
        // Reset the list of commands already played
        _previousCommands = NSMutableArray()

        waitingForInput()

        // Back to the top
        activeItem = rootItem

        postChanged(withAnimate: false,
                    keepActiveVisible: false)
    }

    func interpreterStop() {
        activeItem = nil
        postChanged(withAnimate: false,
                    keepActiveVisible: false)
    }

    @objc(isTheWinningItem:)
    func isTheWinning(_ winningItem: IFSkeinItem?) -> Bool {
        return self.winningItem === winningItem
    }

    // MARK: - Creating an input receiver

    @objc(inputSourceFromSkeinItem:toItem:)
    class func inputSource(from item1: IFSkeinItem?,
                           to item2: IFSkeinItem?) -> ZoomViewInputSource? {
        // item1 must be a parent of item2, and neither can be nil

        // item1 is not executed
        guard let item1, let item2 else { return nil }

        var commandsToExecute: [String] = []
        var parent: IFSkeinItem = item2

        while parent !== item1 {
            let cmd: String = parent.command ?? ""
            commandsToExecute.append(cmd)

            guard let grandparent = parent.parent else { return nil }
            parent = grandparent
        }

        // commandsToExecute contains the list of commands we need to execute
        let source = TestCommands(commands: commandsToExecute)

        return source
    }

    // MARK: - Create Transcript

    func transcript(toPoint item: IFSkeinItem?) -> String {
        var item = item
        if item == nil { item = activeItem }

        // Get the list of items
        var itemList: [IFSkeinItem] = []
        while let thisItem = item {
            itemList.append(thisItem)

            item = thisItem.parent
        }

        let result = NSMutableString()
        while itemList.count > 0 {
            // Retrieve the next item
            let thisItem = itemList.removeLast()

            // Add it to the transcript
            if thisItem !== rootItem {
                result.append(thisItem.command)
                result.append("\n")
            }
            if thisItem.actual != nil {
                result.append(thisItem.actual)
            }
        }

        return result as String
    }

    // Return the first node with differences, or the active node
    var nodeToReport: IFSkeinItem? {
        guard let activeItem else {
            return nil
        }

        var differedItem = activeItem
        var item: IFSkeinItem? = activeItem
        while let thisItem = item {
            if thisItem.hasDifferences {
                differedItem = thisItem
            }
            item = thisItem.parent
        }
        return differedItem
    }

    var reportStateForSkein: String {
        if !rootItem.hasIdeal {
            return "cursed"
        }

        var item = activeItem
        while let thisItem = item {
            if thisItem.hasDifferences {
                return "wrong"
            }
            item = thisItem.parent
        }
        return "right"
    }

    // MARK: - Undo Support
    @objc private func didUndo(_ not: Notification) {
        // Updates the skein UI after an undo changes the model.

        // All types of undo come through here (e.g. including edits to the story source), so
        // the dirty flag is checked to see if the skein has actually changed before telling it
        // to perform it's layout.
        if dirtyLayout {
            postChanged(withAnimate: true,
                        keepActiveVisible: true)
        }
    }

    @objc private func didRedo(_ not: Notification) {
        if dirtyLayout {
            postChanged(withAnimate: true,
                        keepActiveVisible: true)
        }
    }

    // Undo helper functions

    // When modifying the skein, all undo targets are set to be the IFSkein. This means we can
    // remove all skein changes from the undo stack, via [undoManager removeAllActionsWithTarget:]
    // but preserve any other types of undos, e.g changes to the source text.
    //
    // For example: If we play the story, we update the skein as each command is entered (and we
    // don't want to undo these changes). We also clear the undo stack of any skein changes (since
    // we can't undo them), but leave the undo stack's changes to the source text intact.

    func setParentOf(_ item: IFSkeinItem, parent newParent: IFSkeinItem?) {
        item.parent = newParent
    }

    func remove(fromChildrenArrayOf item: IFSkeinItem, itemToRemove: IFSkeinItem) {
        item.remove(fromChildrenArray: itemToRemove)
    }

    func add(toChildrenArrayOf item: IFSkeinItem, itemToAdd: IFSkeinItem) {
        item.add(toChildrenArray: itemToAdd)
    }

    func setCommandOf(_ item: IFSkeinItem, command newCommand: String?) {
        item.command = newCommand
    }

    func setIdealOf(_ item: IFSkeinItem, ideal newIdeal: String?) {
        item.ideal = newIdeal
    }

    func setActualOf(_ item: IFSkeinItem, actual newActual: String?) {
        item.actual = newActual
    }

    @objc(setIsTestSubItemWithNSNumberOf:isTestSubItemWithNSNumber:)
    func setIsTestSubItemWithNSNumberOf(_ item: IFSkeinItem, isTestSubItemWith newIsTestSubItem: NSNumber) {
        item.setIsTestSubItemWith(newIsTestSubItem)
    }
}

// MARK: - Dealing with/creating XML data

/// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node)
private func idForNode(_ item: IFSkeinItem) -> String {
    return "node-\(item.uniqueId)"
}

@objc(IFSkeinXML) @implementation extension IFSkein {

    // Helper function
    private static func firstChildOf(_ element: XMLElement,
                                     withName name: String) -> XMLElement? {
        let childrenWithName = element.elements(forName: name)
        if childrenWithName.count > 0 {
            return childrenWithName[0]
        }
        return nil
    }

    private func decomposeRecursively(_ item: IFSkeinItem?) {
        if let item, item.isTestSubItem == false {
            _ = item.decompose
        }
        for child in item?.children ?? [] {
            decomposeRecursively(child)
        }
    }

    // Read XML Data into Skein
    func parseXmlData(_ data: Data) -> Bool {
        let xmlDoc: XMLDocument
        do {
            xmlDoc = try XMLDocument(data: data,
                                     options: [])
        } catch let error as NSError {
            NSLog("Error reading XML. \"%@\" (code %ld)\n", error, error.code)
            return false
        }

        if xmlDoc.rootElement()?.name != "Skein" {
            NSLog("Could not find root 'Skein' in XML\n")
        }
        guard let rootNodeId = xmlDoc.rootElement()?.attribute(forName: "rootNode")?.stringValue else {
            NSLog("IFSkein: No root node ID specified")
            return false
        }

        // Item dictionary: populate with items ready to be linked together
        let itemDictionary = NSMutableDictionary()

        let items = xmlDoc.rootElement()?.elements(forName: "item") ?? []

        for item in items {
            guard let itemNodeId = item.attribute(forName: "nodeId")?.stringValue else {
                NSLog("IFSkein: Warning - found item with no ID")
                continue
            }

            var command = IFSkein.firstChildOf(item, withName: "command")?.stringValue
            let annotation = IFSkein.firstChildOf(item, withName: "annotation")?.stringValue
            let actual  = IFSkein.firstChildOf(item, withName: "result")?.stringValue
            let ideal   = IFSkein.firstChildOf(item, withName: "commentary")?.stringValue

            if command == nil {
                //NSLog(@"IFSkein: Warning: item with no command found");
                command = ""
            }

            let newItem = IFSkeinItem(skein: self, command: command)
            if (annotation as NSString?)?.starts(with: "***") == true {
                winningItem = newItem
            }
            newItem.actual = actual
            newItem.ideal = ideal

            itemDictionary[itemNodeId] = newItem
        }

        // Item dictionary II: fill in the item children
        for item in items {
            guard let itemNodeId = item.attribute(forName: "nodeId")?.stringValue else {
                continue
            }

            guard let newItem = itemDictionary[itemNodeId] as? IFSkeinItem else {
                // Should never happen
                NSLog("IFSkein: item node not found in dictionary (item ID: %@)", itemNodeId)
                return false
            }

            // Item children
            let itemChildren = IFSkein.firstChildOf(item, withName: "children")
            let itemKids = itemChildren?.elements(forName: "child") ?? []

            for child in itemKids {
                guard let kidNodeId = child.attribute(forName: "nodeId")?.stringValue else {
                    NSLog("IFSkein: Warning: Child item with no node id")
                    continue
                }

                guard let kidItem = itemDictionary[kidNodeId] as? IFSkeinItem else {
                    NSLog("IFSkein: Warning: unable to find node %@", kidNodeId)
                    continue
                }

                let newKid = newItem.addChild(kidItem)
                itemDictionary[kidNodeId] = newKid
            }
        }

        // Root item
        guard let newRoot = itemDictionary[rootNodeId] as? IFSkeinItem else {
            NSLog("IFSkein: No root node")
            return false
        }

        _rootItem = newRoot
        activeItem = nil

        // Decompose "test me" style commands recursively
        decomposeRecursively(rootItem)

        return true
    }

    // MARK: - Create XML

    // Helper methods
    @discardableResult
    private static func addAttribute(_ element: XMLElement,
                                     name attributeName: String,
                                     value: String) -> XMLNode {
        let attributeNode = XMLNode(kind: .attribute, options: .nodePrettyPrint)
        attributeNode.name        = attributeName
        attributeNode.stringValue = value

        element.addAttribute(attributeNode)

        return attributeNode
    }

    private static func element(withName elementName: String,
                                attributeName: String,
                                attributeValue: String) -> XMLElement {
        let root = XMLElement(kind: .element, options: .nodePrettyPrint)
        root.name = elementName
        IFSkein.addAttribute(root,
                             name: attributeName,
                             value: attributeValue)
        return root
    }

    private static func element(withName elementName: String,
                                value: String,
                                preserveWhitespace: Bool) -> XMLElement {
        var options: XMLNode.Options = preserveWhitespace ? .nodePreserveWhitespace : []
        options.insert(.nodePrettyPrint)
        let root = XMLElement(kind: .element,
                              options: options)
        if preserveWhitespace {
            IFSkein.addAttribute(root,
                                 name: "xml:space",
                                 value: "preserve")
        }
        root.name        = elementName
        root.stringValue = value

        return root
    }

    @objc(XMLString)
    var xmlString: String {
        @objc(getXMLString)
        get {
            let root = IFSkein.element(withName: "Skein",
                                       attributeName: "rootNode",
                                       attributeValue: idForNode(rootItem))

            let xmlDoc = XMLDocument(kind: .document,
                                     options: [.documentTidyXML, .nodePrettyPrint])
            xmlDoc.setRootElement(root)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleGetInfoString")
            let generator = "Inform Mac Client (\(version.map { String(describing: $0) } ?? "(null)"))"
            root.addChild(IFSkein.element(withName: "generator", value: generator, preserveWhitespace: false))

            // Write items
            var itemStack: [IFSkeinItem] = []
            itemStack.append(rootItem)

            while itemStack.count > 0 {
                // Pop from the stack
                let node = itemStack.removeLast()

                // Push any children of this node
                itemStack.append(contentsOf: node.children)

                // We only output non-test nodes
                if !node.isTestSubItem {
                    // Add XML
                    let item = IFSkein.element(withName: "item",
                                               attributeName: "nodeId",
                                               attributeValue: idForNode(node))
                    if node.command != nil {
                        item.addChild(IFSkein.element(withName: "command", value: node.command, preserveWhitespace: true))
                    }
                    let composedActual = node.composedActual
                    let composedIdeal  = node.composedIdeal
                    item.addChild(IFSkein.element(withName: "result",  value: composedActual, preserveWhitespace: true))
                    item.addChild(IFSkein.element(withName: "commentary", value: composedIdeal, preserveWhitespace: true))

                    if winningItem === node {
                        item.addChild(IFSkein.element(withName: "annotation", value: "***", preserveWhitespace: true))
                    }

                    root.addChild(item)

                    if node.children.count > 0 {
                        let children = IFSkein.element(withName: "children", value: "", preserveWhitespace: false)
                        item.addChild(children)

                        for childNode in node.nonTestChildren ?? [] {
                            children.addChild(IFSkein.element(withName: "child",
                                                              attributeName: "nodeId",
                                                              attributeValue: idForNode(childNode)))
                        }
                    }
                }
            }

            return xmlDoc.xmlString(options: .nodePrettyPrint)
        }
    }
}
