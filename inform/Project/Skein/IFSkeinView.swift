//
//  IFSkeinView.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import AppKit

/// Constants
private let kSkeinMinEditFieldWidth: CGFloat = 40.0    // Smallest width for editing a command

/// Drawing info, made when first used
@MainActor private var itemTextAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.black,
]

@objc @implementation extension IFSkeinView {
    private final var _skein: IFSkein?
    private final var _layoutTree = IFSkeinLayout()
    private final var _selectedItem: IFSkeinItem?

    weak var delegate: IFSkeinViewDelegate?

    // Drag scrolling
    private final var dragScrolling = false
    private final var dragOrigin = NSPoint.zero
    private final var dragInitialVisible = NSRect.zero

    // Cursor
    private final var viewTrackingArea: NSTrackingArea?

    // Editing
    private final var itemToEdit: IFSkeinItem?
    private final var fieldScroller: NSScrollView?
    private final var fieldEditor: NSTextView?

    // Context menu item
    private final var contextItem: IFSkeinItem?

    // Manager for child views
    private final var skeinViewChildren: IFSkeinViewChildren!

    public override init(frame: NSRect) {
        super.init(frame: frame)

        _skein = IFSkein(project: nil)

        _layoutTree.rootItem = _skein?.rootItem

        // Manager for the child views
        skeinViewChildren = IFSkeinViewChildren(skeinView: self)

        // Use backing layer
        wantsLayer = true
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the view up either: the skein's nib makes the view with `initWithFrame:`.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override var isFlipped: Bool {
        return true    // true puts the origin at the top left corner of the view (false is bottom left)
    }

    // MARK: - Setting/getting the source

    var skein: IFSkein? {
        get {
            return _skein
        }
        set {
            let sk = newValue
            if _skein === sk { return }

            if let skein = _skein {
                NotificationCenter.default.removeObserver(self,
                                                          name: .IFSkeinChanged,
                                                          object: skein)
            }

            _skein = sk
            _layoutTree.rootItem = sk?.rootItem

            if let skein = _skein {
                // Fixed by Collin Pieper: adding an observer for nil has somewhat unwanted side effects
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(skeinDidChange(_:)),
                                                       name: .IFSkeinChanged,
                                                       object: skein)
            }

            _skein?.activeItem = nil
            _selectedItem = nil
            itemToEdit = nil
            contextItem = nil
            layoutSkein(withAnimation: false)
        }
    }

    var layoutTree: IFSkeinLayout {
        return _layoutTree
    }

    var selectedItem: IFSkeinItem? {
        get {
            return _selectedItem
        }
        set {
            let theSelectedItem = newValue
            if _selectedItem !== theSelectedItem {
                _selectedItem = theSelectedItem

                var userDictionary: [AnyHashable: Any] = [:]
                if let theSelectedItem {
                    userDictionary = [IFSkeinSelectionChangedItemKey: theSelectedItem]
                }
                NotificationCenter.default.post(name: .IFSkeinSelectionChanged,
                                                object: self,
                                                userInfo: userDictionary)
            }
        }
    }

    // MARK: - Laying things out

    @objc private final func skeinDidChange(_ not: Notification) {
        if let selectedItem = _selectedItem {
            if !(_skein?.rootItem.hasDescendant(selectedItem) ?? false) {
                // If the selected item is no longer in the tree...
                if _skein?.rootItem.hasDescendant(_skein?.activeItem) ?? false {
                    // ...select the active item
                    _selectedItem = _skein?.activeItem
                } else {
                    // ...select nothing
                    self.selectedItem = nil
                }
            }
        }

        finishEditing(self)

        let userDictionary    = not.userInfo
        let animate           = (userDictionary?[IFSkeinChangedAnimateKey] as? NSNumber)?.boolValue ?? false
        let keepActiveVisible = (userDictionary?[IFSkeinKeepActiveVisibleKey] as? NSNumber)?.boolValue ?? false

        layoutSkein(withAnimation: animate)

        if keepActiveVisible, let activeItem = _skein?.activeItem {
            let rect = skeinViewChildren.rect(for: activeItem)
            if !NSIsEmptyRect(rect) {
                if !NSContainsRect(visibleRect, rect) {
                    scrollToVisible(rect)
                }
            }
        }
    }

    private final func resizeView() {
        var newSize = _layoutTree.size

        // Even if the layout is small, we make sure we fill the superview's frame
        // This ensures we can drag the layout around from anywhere in the panel.
        newSize = NSSize(width:  max(newSize.width,  superview?.frame.size.width ?? 0),
                         height: max(newSize.height, superview?.frame.size.height ?? 0))

        if !NSEqualSizes(newSize, frame.size) {
            setFrameSize(newSize)
        }
    }

    private final func currentMousePosition() -> NSPoint {
        let currentMousePos = window?.mouseLocationOutsideOfEventStream ?? .zero
        return convert(currentMousePos, from: nil)
    }

    public override func updateTrackingAreas() {
        resizeView()

        // Track the current view rect, so we can change it's mouse cursor
        if let viewTrackingArea {
            removeTrackingArea(viewTrackingArea)
            self.viewTrackingArea = nil
        }

        let visibleRect = self.visibleRect
        if !NSIsEmptyRect(visibleRect) {
            var options: NSTrackingArea.Options = [.cursorUpdate, .activeInKeyWindow]

            // Do we start inside the rectangle?
            if NSPointInRect(currentMousePosition(), visibleRect) {
                options.insert(.assumeInside)
            }

            let trackingArea = NSTrackingArea(rect: visibleRect,
                                              options: options,
                                              owner: self,
                                              userInfo: nil)
            viewTrackingArea = trackingArea
            addTrackingArea(trackingArea)
        }

        super.updateTrackingAreas()
    }

    private final func layoutSkein(withAnimation animate: Bool) {
        finishEditing(self)

        // Re-layout this skein
        _layoutTree.rootItem = _skein?.rootItem
        _layoutTree.activeItem = _skein?.activeItem
        _layoutTree.selectedItem = _selectedItem
        _layoutTree.layoutSkein()

        // Tell the report to update itself based on the new skein
        skeinViewChildren.updateReportDetails()

        // Now adjust the layout to take the report into account
        _layoutTree.update(withReportDetails: skeinViewChildren.reportDetails)

        // Resize the view to the size of the new layout
        resizeView()

        // Update views based on new layout, and animate as needed
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = kSkeinAnimationDuration

        skeinViewChildren.update(with: _layoutTree,
                                 animate: animate)

        NSAnimationContext.endGrouping()
    }

    // MARK: Cursor handling

    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    nonisolated public override func awakeFromNib() {
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            // Make sure the skein view doesn't have elasticity
            enclosingScrollView?.horizontalScrollElasticity = .none
            enclosingScrollView?.verticalScrollElasticity = .none
        }
    }

    // MARK: - Mouse handling

    public override func mouseDown(with event: NSEvent) {
        finishEditing(self)

        // We're dragging to move the view around
        NSCursor.closedHand.set()

        dragScrolling = true
        dragOrigin = event.locationInWindow
        dragInitialVisible = visibleRect
    }

    public override func mouseDragged(with event: NSEvent) {
        if dragScrolling {
            let currentPos = event.locationInWindow
            var newVisRect = dragInitialVisible

            newVisRect.origin.x += dragOrigin.x - currentPos.x
            newVisRect.origin.y -= dragOrigin.y - currentPos.y

            // Scroll to the new position
            scrollToVisible(NSIntegralRect(newVisRect))

            NSCursor.closedHand.set()
        }
    }

    public override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
        dragScrolling = false
    }

    // MARK: - Merging knots

    /// The commands of the knots on the way down from a knot to one after it, or nil if it isn't after it
    private static func commandsOnTheWay(from item: IFSkeinItem,
                                         to descendant: IFSkeinItem?) -> [(command: String, isTestSubItem: Bool)]? {
        var commands: [(command: String, isTestSubItem: Bool)] = []
        var current = descendant
        while let knot = current {
            if knot === item {
                return commands.reversed()
            }
            commands.append((knot.command, knot.isTestSubItem))
            current = knot.parent
        }
        return nil
    }

    /// The knot that the given commands lead to from a knot
    private static func item(following commands: [(command: String, isTestSubItem: Bool)],
                             from item: IFSkeinItem) -> IFSkeinItem? {
        var current: IFSkeinItem? = item
        for step in commands {
            current = current?.child(withCommand: step.command, isTestSubItem: step.isTestSubItem)
        }
        return current
    }

    /// Adds a knot to a parent, which merges it into the parent's knot with the same command, if it has one, and so
    /// on, knot by knot, down each thread: a knot that matches one already there is dropped. The knot being played,
    /// the selected knot and the winning knot go to the knots they're merged into.
    @discardableResult
    private final func add(_ item: IFSkeinItem, to parent: IFSkeinItem) -> IFSkeinItem {
        let activeCommands   = IFSkeinView.commandsOnTheWay(from: item, to: _skein?.activeItem)
        let selectedCommands = IFSkeinView.commandsOnTheWay(from: item, to: _selectedItem)
        let winningCommands  = IFSkeinView.commandsOnTheWay(from: item, to: _skein?.winningItem)

        let addedItem = parent.addChild(item)

        if let activeCommands {
            _skein?.activeItem = IFSkeinView.item(following: activeCommands, from: addedItem)
        }
        if let selectedCommands {
            self.selectedItem = IFSkeinView.item(following: selectedCommands, from: addedItem)
        }
        if let winningCommands {
            _skein?.winningItem = IFSkeinView.item(following: winningCommands, from: addedItem)
        }
        return addedItem
    }

    // MARK: - Editing items

    @objc(textDidEndEditing:)
    func textDidEndEditing(_ aNotification: Notification) {
        // Check if the user left the field before committing changes and end the edit.
        let movement = (aNotification.userInfo?[NSText.movementUserInfoKey] as? NSNumber)?.intValue ?? 0
        let success = movement != NSTextMovement.other.rawValue

        if success {
            finishEditing(fieldEditor)      // Store the results
        } else {
            cancelEditing(fieldEditor)      // Abort the edit
        }
    }

    private final func finishEditing(_ sender: Any?) {
        if let itemToEdit, let fieldEditor {
            let parent = itemToEdit.parent

            // Is there already a child with the same command?
            let siblingAlreadyHasSameCommand = (parent?.child(withCommand: fieldEditor.string,
                                                              isTestSubItem: false) !== itemToEdit)

            // (An item being edited has a parent, as the start's command can't be edited)
            if siblingAlreadyHasSameCommand, let parent {
                // Removing then re-adding the item back into the tree merges the itemToEdit with the existing tree
                itemToEdit.removeFromParent()

                // Set the new command
                itemToEdit.command = fieldEditor.string

                add(itemToEdit, to: parent)
            } else {
                // Set the new command
                itemToEdit.command = fieldEditor.string
            }

            cancelEditing(self)
            _skein?.postChanged(withAnimate: true,
                                keepActiveVisible: false)
        } else {
            cancelEditing(self)
        }
        self.itemToEdit = nil
    }

    private final func cancelEditing(_ sender: Any?) {
        needsDisplay = true
        fieldScroller?.removeFromSuperview()

        guard let fieldEditor else { return }

        // Kill off the field editor
        fieldEditor.removeFromSuperview()
        window?.makeFirstResponder(self)

        self.fieldEditor = nil
        itemToEdit = nil
    }

    private final func editItem(_ skeinItem: IFSkeinItem) {
        // Finish any existing editing
        finishEditing(self)
        window?.makeFirstResponder(self)

        if skeinItem.parent == nil {
            // Can't edit the root item
            NSSound.beep()
            return
        }

        // Allows you to edit an item's command
        guard let layoutItem = skeinViewChildren.layoutItem(for: skeinItem) else {
            NSLog("IFSkeinView: Item not found for editing")
            return
        }

        // Get the text to edit
        let itemText = skeinItem.command ?? ""

        // Area of the text for this item
        var itemFrame = layoutItem.textRect

        // Make sure the item is wide enough for editing
        if itemFrame.size.width < kSkeinMinEditFieldWidth {
            itemFrame.origin.x  -= (kSkeinMinEditFieldWidth - itemFrame.size.width) / 2.0
            itemFrame.size.width = kSkeinMinEditFieldWidth
        }

        // 'overflow' border
        itemFrame.origin.x      = floor(itemFrame.origin.x - 14.0)
        itemFrame.origin.y      = floor(itemFrame.origin.y + 4.0)
        itemFrame.size.width    = floor(itemFrame.size.width + 20.0)
        itemFrame.size.height   = floor(itemFrame.size.height)

        scrollToVisible(itemFrame)

        itemToEdit = skeinItem

        // Construct the scroll view
        let fieldScroller: NSScrollView
        if let existingScroller = self.fieldScroller {
            fieldScroller = existingScroller
        } else {
            fieldScroller = NSScrollView()

            fieldScroller.hasHorizontalScroller = false
            fieldScroller.hasVerticalScroller = false
            fieldScroller.borderType = .grooveBorder
            self.fieldScroller = fieldScroller
        }

        // Construct the field editor
        let fieldEditor = window?.fieldEditor(true, for: self) as? NSTextView
        self.fieldEditor = fieldEditor

        let fieldStorage = NSTextStorage(string: itemText,
                                         attributes: itemTextAttributes)
        fieldEditor?.textStorage?.setAttributedString(fieldStorage)

        fieldEditor?.delegate = self
        fieldScroller.frame = itemFrame
        fieldEditor?.frame = itemFrame

        fieldEditor?.alignment = .center
        fieldEditor?.font = itemTextAttributes[.font] as? NSFont

        fieldEditor?.isRichText = false
        fieldEditor?.allowsDocumentBackgroundColorChange = false
        fieldEditor?.backgroundColor = .white

        fieldEditor?.textContainer?.containerSize = NSSize(width: itemFrame.size.width - 4.0, height: 1e6)
        fieldEditor?.textContainer?.widthTracksTextView = false
        fieldEditor?.textContainer?.heightTracksTextView = false
        fieldEditor?.isHorizontallyResizable = false
        fieldEditor?.isVerticallyResizable = true
        fieldEditor?.drawsBackground = true
        fieldEditor?.isEditable = true

        // Activate it
        fieldScroller.documentView = fieldEditor
        addSubview(fieldScroller)
        window?.makeFirstResponder(fieldEditor)
    }

    // MARK: - Playing the game

    private final func playToPoint(_ item: IFSkeinItem) {
        if !canPlayToHere(item) {
            return
        }

        guard let delegate,
              delegate.responds(to: #selector(IFSkeinViewDelegate.stopGame)),
              delegate.responds(to: #selector(IFSkeinViewDelegate.play(toPoint:fromPoint:))) else {
            // Can't play to this point: delegate does not support it
            return
        }

        // Work out if we can play from the active item or not
        if let activeItem = _skein?.activeItem, activeItem.hasDescendant(item) {
            // Play from the active item
            delegate.play(toPoint: item,
                          fromPoint: activeItem)
        } else {
            // We need to play from the start
            delegate.stopGame()
            if let rootItem = _skein?.rootItem {
                delegate.play(toPoint: item,
                              fromPoint: rootItem)
            }
        }
    }

    // MARK: - Moving around

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        finishEditing(self)
    }

    public override func viewWillMove(toSuperview newSuperview: NSView?) {
        finishEditing(self)
    }

    // MARK: - Menu support

    private final func canDelete(_ skeinItem: IFSkeinItem) -> Bool {
        let itemParent = skeinItem.parent

        if itemParent == nil { return false }
        if skeinItem.isTestSubItem { return false }

        if skeinItem.hasDescendant(_skein?.activeItem) {
            return false
        }

        return true
    }

    private final func canPlayToHere(_ item: IFSkeinItem) -> Bool {
        return !item.isTestSubItem
    }

    private final func canInsertPreviousItem(_ item: IFSkeinItem) -> Bool {
        if item.parent == nil { return false }
        if item.isTestSubItem { return false }
        return true
    }

    private final func canInsertNextItem(_ item: IFSkeinItem) -> Bool {
        if item.children.count == 0 {
            return true
        }
        if item.children.count == 1 {
            let firstChild = item.children[0]
            if !firstChild.isTestSubItem { return true }
        }
        return false
    }

    private final func canDeleteItem(_ item: IFSkeinItem) -> Bool {
        return canDelete(item)
    }

    private final func canEditItem(_ item: IFSkeinItem) -> Bool {
        if item.parent == nil { return false }
        if item.isTestSubItem { return false }
        return true
    }

    private final func canSetWinningItem(_ item: IFSkeinItem) -> Bool {
        if item.parent == nil { return false }
        if item.isTestSubItem { return false }
        return true
    }

    private final func canSplitThread(_ item: IFSkeinItem) -> Bool {
        if item.children.count > 0 {
            let firstChild = item.children[0]
            if firstChild.isTestSubItem {
                return false
            }
        }
        return true
    }

    private final func canDeleteThread(_ item: IFSkeinItem) -> Bool {
        if item.parent == nil {
            // The threads from the start can go, unless the story has been played beyond the start
            return (item === _skein?.activeItem) || !item.hasDescendant(_skein?.activeItem)
        }
        return canDelete(item)
    }

    func hasMenu(_ item: IFSkeinItem) -> Bool {
        if !item.isTestSubItem { return true }
        if item.children.count == 0 { return true }

        let firstChild = item.children[0]
        if !firstChild.isTestSubItem { return true }

        return false
    }

    // MARK: - Context menu

    @objc(menuForItem:)
    func menu(for item: IFSkeinItem) -> NSMenu {
        contextItem = item

        let contextMenu = NSMenu()
        contextMenu.autoenablesItems = false

        // Add menu items for the standard actions
        var menuItem: NSMenuItem
        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Play to Here"),
                                       action: #selector(playToHere(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canPlayToHere(item)

        // -----------------------------------------------
        contextMenu.addItem(NSMenuItem.separator())

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Insert Previous Command"),
                                       action: #selector(insertPreviousItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canInsertPreviousItem(item)

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Insert Next Command"),
                                       action: #selector(insertNextItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canInsertNextItem(item)

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Delete Command"),
                                       action: #selector(deleteOneItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canDeleteItem(item)

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Edit Command"),
                                       action: #selector(editContextItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canEditItem(item)

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Set Winning Command"),
                                       action: #selector(setWinningCommandItem(_:)),
                                       keyEquivalent: "")
        if _skein?.isTheWinning(item) ?? false {
            menuItem.state = .on
        } else {
            menuItem.state = .off
        }
        menuItem.isEnabled = canSetWinningItem(item)
        // -----------------------------------------------
        contextMenu.addItem(NSMenuItem.separator())

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Split Thread"),
                                       action: #selector(addNewBranch(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canSplitThread(item)

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Delete Threads from Here"),
                                       action: #selector(deleteItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = canDeleteThread(item)

        // -----------------------------------------------
        contextMenu.addItem(NSMenuItem.separator())
        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Bless Command"),
                                       action: #selector(blessItem(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = true

        menuItem = contextMenu.addItem(withTitle: IFUtility.localizedString("Bless all Commands to Here"),
                                       action: #selector(blessToHere(_:)),
                                       keyEquivalent: "")
        menuItem.isEnabled = true

        // Return the menu
        return contextMenu
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        // Find which item that the mouse is over
        var pointInView = event.locationInWindow
        pointInView = convert(pointInView, from: nil)

        guard let itemAtPoint = _layoutTree.item(at: pointInView) else { return nil }

        return menu(for: itemAtPoint)
    }

    // MARK: - Menu actions

    // Each command acts on the knot whose menu was shown, and does nothing without one

    @objc private final func playToHere(_ sender: Any?) {
        guard let contextItem else { return }

        playToPoint(contextItem)
        self.contextItem = nil
    }

    @objc private final func addNewBranch(_ sender: Any?) {
        guard let contextItem else { return }

        if canSplitThread(contextItem) {
            // Add a new, blank item
            let newItem = contextItem.addChild(IFSkeinItem(skein: _skein, command: ""))

            // Update layout based on the changed skein
            _skein?.postChanged(withAnimate: true,
                                keepActiveVisible: false)

            // Edit the item
            editItem(newItem)
        }
        self.contextItem = nil
    }

    @objc private final func insertPreviousItem(_ sender: Any?) {
        guard let contextItem else { return }

        // (The parent can't be nil, as the item can have a previous command inserted)
        if canInsertPreviousItem(contextItem), let parent = contextItem.parent {
            // Remove the item (it will become the child of the new item)
            contextItem.removeFromParent()

            // Add a new, blank item
            let newItem = parent.addChild(IFSkeinItem(skein: _skein, command: ""))

            // Add the item back in again (merging it, if the parent already had a blank item)
            add(contextItem, to: newItem)

            // Update layout based on the changed skein
            _skein?.postChanged(withAnimate: true,
                                keepActiveVisible: false)

            // Edit the item
            editItem(newItem)
        }
        self.contextItem = nil
    }

    @objc private final func insertNextItem(_ sender: Any?) {
        guard let contextItem else { return }

        if canInsertNextItem(contextItem) {
            if contextItem.children.count == 1 {
                self.contextItem = contextItem.children[0]
                insertPreviousItem(sender)
            } else if contextItem.children.count == 0 {
                addNewBranch(sender)
            }
        }
        self.contextItem = nil
    }

    @objc private final func deleteItem(_ sender: Any?) {
        guard let contextItem else { return }

        if canDeleteThread(contextItem) {
            let fixSelectedItem = contextItem.hasDescendant(_selectedItem)

            if contextItem.parent == nil {
                while contextItem.children.count > 0 {
                    contextItem.children[0].removeFromParent()
                }
                self.selectedItem = nil
            } else {
                let parent = contextItem.parent
                contextItem.removeFromParent()

                // Adjust the selected item to remain valid
                if fixSelectedItem {
                    if (parent?.children.count ?? 0) <= 1 {
                        self.selectedItem = parent
                    } else {
                        self.selectedItem = nil
                    }
                }
            }

            // Force a layout of the skein
            _skein?.postChanged(withAnimate: true,
                                keepActiveVisible: false)
        }
        self.contextItem = nil
    }

    @objc private final func deleteOneItem(_ sender: Any?) {
        guard let contextItem else { return }

        // (The parent can't be nil, as the item can be deleted)
        if canDeleteItem(contextItem), let originalParent = contextItem.parent {
            // Work out which is the last dependent item spawned by our potential "test me" command
            var dependentLeaf = contextItem
            while dependentLeaf.children.count == 1 {
                let child = dependentLeaf.children[0]
                if !child.isTestSubItem {
                    break
                }
                dependentLeaf = child
            }

            // Remember the children of this item
            let children = dependentLeaf.children

            // Is the selected item one that's deleted? (One after them goes with the children.)
            let fixSelectedItem = contextItem.hasDescendant(_selectedItem)
                                  && !children.contains { $0.hasDescendant(_selectedItem) }

            // Remove them from the tree
            for child in children {
                child.removeFromParent()
            }

            // Remove this item (and any children)
            contextItem.removeFromParent()

            // Add the children back to the parent item (merging if necessary)
            for child in children {
                add(child, to: originalParent)
            }

            // Adjust the selected item to remain valid
            if fixSelectedItem {
                if originalParent.children.count <= 1 {
                    self.selectedItem = originalParent
                } else {
                    self.selectedItem = nil
                }
            }

            // Force a layout of the skein
            _skein?.postChanged(withAnimate: true,
                                keepActiveVisible: false)
        }
        self.contextItem = nil
    }

    @objc private final func setWinningCommandItem(_ sender: Any?) {
        guard let contextItem else { return }

        if canSetWinningItem(contextItem) {
            let oldWinningItem = _skein?.winningItem
            if oldWinningItem === contextItem {
                _skein?.winningItem = nil
            } else {
                _skein?.winningItem = contextItem
            }

            if let oldWinningItem {
                // redraw the old item, to remove the winning item star icon
                let oldWinningView = skeinViewChildren.itemView(for: oldWinningItem)
                oldWinningView?.needsDisplay = true
            }

            // Force a layout of the skein, making the new winning item appear
            _skein?.postChanged(withAnimate: false,
                                keepActiveVisible: false)
        }
        self.contextItem = nil
    }

    @objc private final func editContextItem(_ sender: Any?) {
        guard let contextItem else { return }

        if canEditItem(contextItem) {
            editItem(contextItem)
        }
        self.contextItem = nil
    }

    @objc private final func blessItem(_ sender: Any?) {
        guard let contextItem else { return }

        contextItem.ideal = contextItem.actual

        // Force a layout of the skein
        _skein?.postChanged(withAnimate: false,
                            keepActiveVisible: false)
    }

    @objc private final func blessToHere(_ sender: Any?) {
        guard contextItem != nil else { return }

        while let item = contextItem {
            item.ideal = item.actual
            contextItem = item.parent
        }

        // Force a layout of the skein
        _skein?.postChanged(withAnimate: false,
                            keepActiveVisible: false)
    }

    func saveTranscript(_ sender: Any?) {
        guard let window else { return }
        if _layoutTree.rootLayoutItem?.onSelectedLine != true { return }

        let string = _skein?.transcript(toPoint: _layoutTree.rootLayoutItem?.leafSelectedLine?.item) ?? ""

        IFUtility.saveTranscriptPanel(with: string,
                                      window: window)
    }

    @objc(itemAtPoint:)
    func item(at point: NSPoint) -> IFSkeinItem? {
        return _layoutTree.item(at: point)
    }

    @objc(selectItem:withAnimation:)
    func select(_ item: IFSkeinItem?, withAnimation animate: Bool) {
        if _selectedItem !== item {
            self.selectedItem = item
            layoutSkein(withAnimation: animate)
        }
        scrollViewToItem(item)
    }

    func selectItem(withNodeId skeinItemNodeId: UInt) -> Bool {
        if let item = _skein?.rootItem.find(withNodeId: skeinItemNodeId) {
            select(item, withAnimation: false)
            return true
        }
        return false
    }

    private final func scrollViewToItem(_ scrollToItem: IFSkeinItem?) {
        guard let scrollToItem else { return }

        let rect = skeinViewChildren.rect(for: scrollToItem)
        if !NSIsEmptyRect(rect) {
            scrollToVisible(rect)
        }
    }

    func setItemBlessed(_ item: IFSkeinItem, bless: Bool) {
        if bless {
            item.ideal = item.actual
        } else {
            item.ideal = ""
        }

        // Force a layout of the skein
        _skein?.postChanged(withAnimate: false,
                            keepActiveVisible: false)
    }

    class var fontSize: CGFloat {
        return kSkeinDefaultItemFontSize * IFPreferences.shared.appFontSizeMultiplier
    }

    func fontSizePreferenceChanged(_ not: Notification) {
        // Adjust edit field text size
        itemTextAttributes = IFUtility.adjustAttributesFontSize(itemTextAttributes, size: type(of: self).fontSize)

        // Adjust child views
        skeinViewChildren.fontSizePreferenceChanged()

        // Mark skein as needing to recalculate command sizes
        _skein?.rootItem.forceCommandSizeChangeRecursively()

        // Update layout
        _skein?.postChanged(withAnimate: false,
                            keepActiveVisible: false)
    }

    private final func recursiveCheckItems(_ checkFunction: (IFSkeinLayoutItem) -> Bool) -> Bool {
        guard let rootLayoutItem = _layoutTree.rootLayoutItem else {
            return false
        }
        var queue: [IFSkeinLayoutItem] = []

        queue.append(rootLayoutItem)
        while queue.count > 0 {
            let layoutItem = queue.removeLast()

            if checkFunction(layoutItem) {
                return true
            }
            queue.append(contentsOf: layoutItem.children ?? [])
        }
        return false
    }

    @objc(anyItemPurple)
    var isAnyItemPurple: Bool {
        @objc(isAnyItemPurple) get {
            return recursiveCheckItems { layoutItem in
                return layoutItem.recentlyPlayed
            }
        }
    }

    @objc(anyItemGrey)
    var isAnyItemGrey: Bool {
        @objc(isAnyItemGrey) get {
            return recursiveCheckItems { layoutItem in
                return !layoutItem.recentlyPlayed && !layoutItem.onSelectedLine
            }
        }
    }

    @objc(anyItemBlue)
    var isAnyItemBlue: Bool {
        @objc(isAnyItemBlue) get {
            return recursiveCheckItems { layoutItem in
                return !layoutItem.recentlyPlayed && layoutItem.onSelectedLine
            }
        }
    }

    @objc(reportVisible)
    var isReportVisible: Bool {
        @objc(isReportVisible) get {
            return _layoutTree.selectedItem != nil
        }
    }

    @objc(tickVisible)
    var isTickVisible: Bool {
        @objc(isTickVisible) get {
            if let selectedLayoutItem = _layoutTree.selectedLayoutItem {
                // Go to leaf of selected line
                var layoutItem: IFSkeinLayoutItem? = selectedLayoutItem
                while let selectedLineChild = layoutItem?.selectedLineChild {
                    layoutItem = selectedLineChild
                }

                // Has anything on the selected line got differences?
                while let currentItem = layoutItem {
                    if currentItem.item.hasDifferences {
                        return true
                    }
                    layoutItem = currentItem.parent
                }
            }
            return false
        }
    }

    @objc(crossVisible)
    var isCrossVisible: Bool {
        @objc(isCrossVisible) get {
            if let selectedLayoutItem = _layoutTree.selectedLayoutItem {
                // Go to leaf of selected line
                var layoutItem: IFSkeinLayoutItem? = selectedLayoutItem
                while let selectedLineChild = layoutItem?.selectedLineChild {
                    layoutItem = selectedLineChild
                }

                // Has anything on the selected line got differences?
                while let currentItem = layoutItem {
                    if !currentItem.item.hasDifferences {
                        return true
                    }
                    layoutItem = currentItem.parent
                }
            }
            return false
        }
    }

    @objc(badgedItemVisible)
    var isBadgedItemVisible: Bool {
        @objc(isBadgedItemVisible) get {
            return recursiveCheckItems { layoutItem in
                return layoutItem.item.hasBadge
            }
        }
    }

    var itemsVisible: Int {
        var count = 0
        _ = recursiveCheckItems { _ in
            count += 1
            return false
        }

        return count
    }
}
