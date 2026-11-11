//
//  IFHeaderView.swift
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

import Cocoa

/// A root header node for the root header given, or for no headers when that's nil
@MainActor private func rootNode(withHeader header: IFHeader?) -> IFHeaderNode {
    let header = header ?? IFHeader(name: "", parent: nil, children: nil)
    return IFHeaderNode(header: header,
                        position: NSPoint(x: 0, y: 0),
                        depth: 0)
}

@objc @implementation extension IFHeaderView {
    /// The display depth for this view
    private final var _displayDepth: Int32 = 5
    /// The root header that this view should display
    private final var rootHeader: IFHeader?
    /// The root header node
    private final var _rootHeaderNode: IFHeaderNode = rootNode(withHeader: nil)
    /// The header node that we're editing at the moment
    private final var editNode: IFHeaderNode?
    private final var _backgroundColour: NSColor = NSColor.white.copy() as! NSColor

    /// The text view that's performing editing at the moment
    private final var editor: NSTextView?
    /// Text storage for the field editor
    private final var editStorage: NSTextStorage?

    weak var delegate: IFHeaderViewDelegate?

    private final var _message: String?

    // MARK: - Initialisation

    public override init(frame: NSRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Information about this view

    var rootHeaderNode: IFHeaderNode {
        return _rootHeaderNode
    }

    // MARK: - Updating the view

    private final func sizeView() {
        // Resize the view
        var rootFrame = _rootHeaderNode.frame
        rootFrame.size.width = self.frame.size.width
        rootFrame.size.height += 5

        if _message != nil, let enclosingScrollView = self.enclosingScrollView {
            rootFrame.size = enclosingScrollView.contentSize
            self.autoresizingMask = self.autoresizingMask.union(.height)
        } else {
            self.autoresizingMask = self.autoresizingMask.subtracting(.height)
        }

        setFrameSize(rootFrame.size)
    }

    private final func updateFromRoot() {
        // Replace the root header node
        _rootHeaderNode = rootNode(withHeader: rootHeader)
        var populateToDepth = _displayDepth
        // HACK: If on level 5, include level 6 (examples)
        if populateToDepth == 5 {
            populateToDepth += 1
        }

        _rootHeaderNode.populate(toDepth: populateToDepth)

        // Add a message if necessary
        if (_rootHeaderNode.children?.count ?? 0) == 0 {
            if (rootHeader?.children.count ?? 0) == 0 {
                self.message = IFUtility.localizedString("NoHeadingsSet",
                                                         default: "")
            } else {
                self.message = IFUtility.localizedString("NoHeadingsVisible",
                                                         default: "")
            }
        } else {
            _message = nil
        }

        // Redraw the display
        sizeView()
        needsDisplay = true
    }

    var message: String? {
        get {
            return _message
        }
        set {
            var newMessage = newValue
            if newMessage?.isEmpty ?? true {
                newMessage = nil
            }
            _message = newMessage

            sizeView()
            needsDisplay = true
        }
    }

    // MARK: - Settings for this view

    public override var isFlipped: Bool {
        return true
    }

    var displayDepth: Int32 {
        get {
            return _displayDepth
        }
        set {
            // Set the display depth for this view
            _displayDepth = newValue

            // Refresh the view
            updateFromRoot()
        }
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    var backgroundColour: NSColor {
        get {
            return _backgroundColour
        }
        set {
            _backgroundColour = newValue.copy() as! NSColor
        }
    }

    // MARK: - Drawing

    public override func draw(_ rect: NSRect) {
        // Draw the background
        _backgroundColour.set()
        NSIntersectionRect(rect, self.bounds).fill()

        // Draw the message, if any
        if let message = _message {
            // Get the style for the message
            let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            style.alignment = .center

            // Find text colour
            var textColour = NSColor.textColor

            let theme = IFPreferences.shared.getCurrentTheme()
            if theme.options.count > Int(IFSyntaxHighlightingOptionType.mainText.rawValue) {
                textColour = theme.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)].colour
            }
            let messageAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12),
                                                                    .foregroundColor: textColour,
                                                                    .paragraphStyle: style]

            // Draw roughly centered
            let bounds = self.bounds
            var textBounds = NSInsetRect(bounds, 8, 8)
            textBounds.origin.y = NSMinY(bounds) + 8
            textBounds.size.height = NSMaxY(bounds) - NSMinY(textBounds)

            (message as NSString).draw(in: textBounds,
                                       withAttributes: messageAttributes)
        } else {
            // Draw the nodes
            _rootHeaderNode.draw(in: rect,
                                 withFrame: self.bounds)
        }
    }

    // MARK: - Messages from the header controller

    func refreshHeaders(_ controller: IFHeaderController) {
        // Get the root header from the controller
        rootHeader = controller.rootHeader

        // Destroy the editor when the headers are updated
        if let editor {
            editor.removeFromSuperview()
            self.editor = nil
        }

        // Update this control
        updateFromRoot()

        delegate?.refreshHeaders?(controller)
    }

    // MARK: - Editing events

    private final func editHeaderNode(_ node: IFHeaderNode,
                                      mouseEvent mouseDown: NSEvent?) {
        if let editor {
            editor.removeFromSuperview()
            self.editor = nil
        }

        // Stop editing the previous node
        editNode?.isEditing = false
        editNode?.selectionStyle = .unselected
        editNode = nil

        // Don't edit the title node
        if node.header.parent == nil {
            return
        }

        // Start editing the next node
        editNode = node
        editNode?.selectionStyle = .inputCursor
        editNode?.isEditing = true

        needsDisplay = true

        // Work out the bounding box of the area to be edited
        var headerNameRect = node.headerTitleRect
        let bounds = self.bounds
        headerNameRect.size.width = NSMaxX(bounds) - NSMinX(headerNameRect)

        // Assign the field editor to ourselves
        let editor = self.window?.fieldEditor(true, for: node) as? NSTextView
        self.editor = editor

        // Set up the editor storage
        let editStorage = self.editStorage ?? NSTextStorage()
        self.editStorage = editStorage
        editStorage.setAttributedString(node.attributedTitle)
        editor?.layoutManager?.replaceTextStorage(editStorage)

        // Set up the field editor
        let bgColour = editNode?.textBackgroundColour ?? _backgroundColour

        if let editor {
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            editor.delegate = self
            editor.isRichText = false
            editor.allowsDocumentBackgroundColorChange = false
            editor.backgroundColor = bgColour
            editor.isHorizontallyResizable = false
            editor.isVerticallyResizable = true
            editor.textContainerInset = NSSize(width: 0, height: 0)

            editor.textContainer?.containerSize = headerNameRect.size
            editor.textContainer?.widthTracksTextView = false
            editor.textContainer?.heightTracksTextView = false
            editor.drawsBackground = false
            if let editNode {
                editor.typingAttributes = editNode.attributes
            }
            editor.textContainer?.lineFragmentPadding = 0

            // Add the field editor
            editor.removeFromSuperview()
            editor.frame = headerNameRect
            addSubview(editor)
        }
        self.window?.makeFirstResponder(editor)

        // Set up the editor storage again
        editStorage.setAttributedString(node.attributedTitle)
        editor?.layoutManager?.replaceTextStorage(editStorage)

        if let mouseDown {
            editor?.mouseDown(with: mouseDown)
        }
    }

    // MARK: - Mouse events

    public override func mouseDown(with theEvent: NSEvent) {
        // Get the position where the mouse was clicked
        let viewPos = convert(theEvent.locationInWindow,
                              from: nil)

        // Get which node was clicked on
        let headingsVisible = (_rootHeaderNode.children?.count ?? 0) > 0
        if headingsVisible {
            var editable = false
            let clicked = _rootHeaderNode.atPoint(viewPos,
                                                  editableOut: &editable)

            if let clicked, editable {
                // Start editing the node
                editHeaderNode(clicked,
                               mouseEvent: theEvent)
            } else {
                // Inform the delegate that the header has been clicked
                if let clicked {
                    delegate?.headerView?(self,
                                          clickedOn: clicked)
                }
            }
        }
    }

    public override func mouseMoved(with theEvent: NSEvent) {
        // Get the position where the mouse was clicked
        let viewPos = convert(theEvent.locationInWindow,
                              from: nil)

        // Get which node was clicked on
        let headingsVisible = (_rootHeaderNode.children?.count ?? 0) > 0
        if !headingsVisible {
            NSCursor.arrow.set()
        } else {
            var editable = false
            let clicked = _rootHeaderNode.atPoint(viewPos,
                                                  editableOut: &editable)
            if clicked != nil {
                if editable {
                    NSCursor.iBeam.set()
                } else {
                    NSCursor.pointingHand.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Field editor delegate events

    func textDidEndEditing(_ aNotification: Notification) {
        // Get the new text for this node
        let newText = editNode?.freshValue(forEditedTitle: editStorage?.string ?? "")

        // Tell the delegate to update the source text, if a node was being edited
        if let editNode, let newText {
            delegate?.headerView?(self,
                                  update: editNode,
                                  withNewTitle: newText)
        }

        // Finished with the edit node
        editNode?.isEditing = false
        editNode?.selectionStyle = .unselected
        editNode = nil

        // Finished with the field editor
        editor?.removeFromSuperview()
        editor = nil

        needsDisplay = true

        // Force an immediately update
        updateFromRoot()
    }

    func setColours(_ bgColour: NSColor) {
        self.backgroundColour = bgColour
    }
}
