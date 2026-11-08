//
//  IFHeaderNode.swift
//  Inform
//
//  Created by Andrew Hunter on 03/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

import Cocoa

// MARK: - Fonts

private let bulletPoint = " • "

// MARK: - Preferences

private let IFHeaderPointSize = "IFHeaderPointSize"
private let IFHeaderMargin    = "IFHeaderMargin"
private let IFHeaderIndent    = "IFHeaderIndent"
private let IFHeaderGap       = "IFHeaderGap"
private let IFHeaderCorner    = "IFHeaderCorner"

/// The fonts for nodes, made after registering the defaults for laying out nodes. Swift makes them once, when they're
/// first used, which is when the first node is made.
private let headerNodeFonts: (regular: NSFont, bold: NSFont) = {
    UserDefaults.standard.register(defaults:
        [IFHeaderPointSize: NSFont.smallSystemFontSize,
         IFHeaderMargin: 5.0,
         IFHeaderIndent: 12.0,
         IFHeaderGap: 8.0,
         IFHeaderCorner: 5.0])

    let pointSize = CGFloat(UserDefaults.standard.float(forKey: IFHeaderPointSize))
    return (NSFont.systemFont(ofSize: pointSize), NSFont.boldSystemFont(ofSize: pointSize))
}()

@objc @implementation extension IFHeaderNode {
    /// The position of this node
    private final var position: NSPoint
    /// The frame for this node, including all its children
    private final var _frame: NSRect = .zero
    /// The frame for this node, not including any children
    private final var exclusiveFrame: NSRect = .zero
    /// The depth of this node in the tree
    private final var depth: Int32
    /// \c YES if we're editing this node
    private final var _editing: Bool = false

    /// The IFHeader item associated with this node
    let header: IFHeader
    /// The child nodes of this node
    private final var _children: [IFHeaderNode]?

    var selectionStyle: IFHeaderNodeSelectionStyle

    // Parameters representing how this node should be laid out
    /// Margin to the items
    private final let margin: CGFloat
    /// Indentation per level
    private final let indent: CGFloat
    /// Vertical gap around items
    private final let gap: CGFloat
    /// Size of a corner for an item
    private final let corner: CGFloat

    // MARK: - Utilities used to help lay out this node

    private final var font: NSFont {
        if depth == 0 {
            return headerNodeFonts.bold
        }

        switch selectionStyle {
        case .selected:
            return headerNodeFonts.bold

        case .unselected, .inputCursor:
            return headerNodeFonts.regular

        @unknown default:
            return headerNodeFonts.regular
        }
    }

    private final var name: String {
        var name = header.headingName
        if depth > 0 {
            name = bulletPoint + name
        }
        return name
    }

    private final func updateNodeFrame() {
        // The frame has an origin at the position specified for this node
        _frame.origin = position

        // The initial height is determined by the title of this node
        _frame.size.width = (name as NSString).size(withAttributes: attributes).width
        _frame.size.height = gap + font.ascender - font.descender

        exclusiveFrame = _frame

        // The total height is different if there are children for this item (depending on the y position of the
        // final child)
        if let children = _children, children.count > 0 {
            // The width is that of the widest child element, which is indented further than this node
            var maxX = NSMaxX(_frame)

            for child in children {
                let childMaxX = NSMaxX(child.frame) + indent
                if childMaxX > maxX {
                    maxX = childMaxX
                }
            }

            _frame.size.width = maxX - NSMinX(_frame)

            // The height is based on the maximum Y position of the final child
            let lastFrame = children.last!.frame
            let maxY = NSMaxY(lastFrame)
            _frame.size.height = maxY - NSMinY(_frame)
        }
    }

    // MARK: - Constructing this node

    init(header newHeader: IFHeader,
         position newPosition: NSPoint,
         depth newDepth: Int32) {
        // If this is the first node, register the defaults and make the fonts
        _ = headerNodeFonts

        // Update the contents of this node
        header = newHeader
        depth = newDepth
        position = newPosition
        selectionStyle = .unselected

        _children = nil

        // Set up the parameters
        margin = CGFloat(UserDefaults.standard.double(forKey: IFHeaderMargin))
        indent = CGFloat(UserDefaults.standard.double(forKey: IFHeaderIndent))
        gap    = CGFloat(UserDefaults.standard.double(forKey: IFHeaderGap))
        corner = CGFloat(UserDefaults.standard.double(forKey: IFHeaderCorner))

        super.init()
    }

    func populate(toDepth maxDepth: Int32) {
        // Do nothing if we've reached the end
        if maxDepth <= (header.symbol?.level ?? 0) {
            _children = nil
            updateNodeFrame()
            return
        }

        // Create the children array
        _children = nil
        updateNodeFrame()
        _children = []

        // Work out the position for the first child node
        var childPoint = NSPoint(x: NSMinX(_frame), y: floor(NSMaxY(_frame)))

        // Populate it
        for childNode in header.children {
            if (childNode.symbol?.level ?? 0) > maxDepth {
                continue
            }

            // Create a new child node
            let newChildNode = IFHeaderNode(header: childNode,
                                            position: childPoint,
                                            depth: depth + 1)

            // Populate it
            newChildNode.populate(toDepth: maxDepth)
            _children?.append(newChildNode)

            // Update the position of the next child element
            childPoint.y = floor(NSMaxY(newChildNode.frame))
        }

        // Update the frame of this node
        updateNodeFrame()
    }

    // MARK: - Getting information about this node

    var frame: NSRect {
        return _frame
    }

    var children: [IFHeaderNode]? {
        guard let _children, _children.count > 0 else {
            return nil
        }
        return _children
    }

    @objc(nodeAtPoint:editableOut:)
    func atPoint(_ point: NSPoint,
                 editableOut: UnsafeMutablePointer<Bool>) -> IFHeaderNode? {
        var indentedFrame = _frame
        indentedFrame.origin.x += margin + CGFloat(depth) * indent

        // If the point is outside the frame for this node, then return nothing
        if NSPointInRect(point, indentedFrame) {
            // If the point is beyond the line border for this item, then search the children
            for child in _children ?? [] {
                if let childNode = child.atPoint(point, editableOut: editableOut) {
                    return childNode
                }
            }
        }

        // Editable section
        if NSPointInRect(point, fullHeaderTitleRect) {
            editableOut.pointee = true
            return self
        }

        // Non-editable section
        indentedFrame = exclusiveFrame
        indentedFrame.origin.x += margin + CGFloat(depth) * indent

        // If within the frame and not any of the children, then the node that was clicked was this node
        if NSPointInRect(point, indentedFrame) {
            editableOut.pointee = false
            return self
        }

        editableOut.pointee = false
        return nil
    }

    @objc(nodeWithLines:intelFile:)
    func withLines(_ lines: NSRange,
                   intelFile intel: IFIntelFile?) -> IFHeaderNode? {
        // FIXME: this more properly belongs in IFHeader (? - won't take account of current child settings there)

        // Get the following symbol
        let symbol = header.symbol
        var followingSymbol = symbol?.sibling

        if followingSymbol == nil {
            var parent = symbol?.parent

            while let currentParent = parent, followingSymbol == nil {
                followingSymbol = currentParent.sibling
                parent = currentParent.parent
            }
        }

        // Work out the line range for this header node (with NSUInteger's arithmetic, as the source page's lines are
        // NSUIntegers)
        let firstLine: UInt
        let finalLine: UInt

        firstLine = intel?.line(for: symbol) ?? 0
        if let followingSymbol {
            finalLine = intel?.line(for: followingSymbol) ?? 0
        } else {
            finalLine = UInt(NSNotFound)
        }

        // If this range does not overlap the symbol range for this symbol, then return nil
        let location = UInt(bitPattern: lines.location)
        let length = UInt(bitPattern: lines.length)
        if symbol != nil {
            if firstLine >= location &+ length { return nil }
            if firstLine > location { return nil }
            if finalLine != UInt(NSNotFound) && location > finalLine { return nil }
        }

        // See if any of the child nodes are better match
        if let children = _children {
            for childNode in children {
                if let foundChild = childNode.withLines(lines, intelFile: intel) {
                    return foundChild
                }
            }
        }

        // This is the header node to use
        return self
    }

    // MARK: - Drawing the node

    private final func highlightPath(for drawFrame: NSRect) -> NSBezierPath {
        // Bezier path representing the outline of this node
        let result = NSBezierPath()
        let depth = CGFloat(self.depth)

        // Draw the border
        result.move(to: NSPoint(x: NSMinX(_frame) + corner + margin + indent * depth + 0.5, y: NSMinY(_frame) + 0.5))
        result.line(to: NSPoint(x: NSMaxX(drawFrame) - corner - margin + 0.5, y: NSMinY(_frame) + 0.5))
        result.curve(to: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMinY(_frame) + corner + 0.5),
                     controlPoint1: NSPoint(x: NSMaxX(drawFrame) - corner/2 - margin + 0.5, y: NSMinY(_frame) + 0.5),
                     controlPoint2: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMinY(_frame) + corner/2 + 0.5))

        result.line(to: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMaxY(_frame) - corner + 0.5))
        result.curve(to: NSPoint(x: NSMaxX(drawFrame) - corner - margin + 0.5, y: NSMaxY(_frame) + 0.5),
                     controlPoint1: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMaxY(_frame) - corner/2 + 0.5),
                     controlPoint2: NSPoint(x: NSMaxX(drawFrame) - corner/2 - margin, y: NSMaxY(_frame)))

        result.line(to: NSPoint(x: NSMinX(_frame) + corner + margin + indent * depth + 0.5, y: NSMaxY(_frame) + 0.5))
        result.curve(to: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5, y: NSMaxY(_frame) - corner + 0.5),
                     controlPoint1: NSPoint(x: NSMinX(_frame) + corner/2 + margin + indent * depth + 0.5,
                                            y: NSMaxY(_frame) + 0.5),
                     controlPoint2: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5,
                                            y: NSMaxY(_frame) - corner/2 + 0.5))

        result.line(to: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5, y: NSMinY(_frame) + corner + 0.5))
        result.curve(to: NSPoint(x: NSMinX(_frame) + corner + margin + indent * depth + 0.5, y: NSMinY(_frame) + 0.5),
                     controlPoint1: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5,
                                            y: NSMinY(_frame) + corner/2 + 0.5),
                     controlPoint2: NSPoint(x: NSMinX(_frame) + corner/2 + margin + indent * depth + 0.5,
                                            y: NSMinY(_frame) + 0.5))

        return result
    }

    private final func truncatedHighlightPath(for drawFrame: NSRect) -> NSBezierPath {
        let height = gap + font.ascender - font.descender
        if height + corner >= _frame.size.height {
            return highlightPath(for: drawFrame)
        }

        // Bezier path representing the outline of this node
        let result = NSBezierPath()
        let depth = CGFloat(self.depth)

        // Draw the border
        result.move(to: NSPoint(x: NSMinX(_frame) + corner + margin + indent * depth + 0.5, y: NSMinY(_frame) + 0.5))
        result.line(to: NSPoint(x: NSMaxX(drawFrame) - corner - margin + 0.5, y: NSMinY(_frame) + 0.5))
        result.curve(to: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMinY(_frame) + corner + 0.5),
                     controlPoint1: NSPoint(x: NSMaxX(drawFrame) - corner/2 - margin + 0.5, y: NSMinY(_frame) + 0.5),
                     controlPoint2: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMinY(_frame) + corner/2 + 0.5))

        result.line(to: NSPoint(x: NSMaxX(drawFrame) - margin + 0.5, y: NSMinY(_frame) + height + 0.5))
        result.line(to: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5, y: NSMinY(_frame) + height + 0.5))

        result.line(to: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5, y: NSMinY(_frame) + corner + 0.5))
        result.curve(to: NSPoint(x: NSMinX(_frame) + corner + margin + indent * depth + 0.5, y: NSMinY(_frame) + 0.5),
                     controlPoint1: NSPoint(x: NSMinX(_frame) + margin + indent * depth + 0.5,
                                            y: NSMinY(_frame) + corner/2 + 0.5),
                     controlPoint2: NSPoint(x: NSMinX(_frame) + corner/2 + margin + indent * depth + 0.5,
                                            y: NSMinY(_frame) + 0.5))

        return result
    }

    var attributes: [NSAttributedString.Key: Any] {
        // Find text colour
        var textColour = NSColor.textColor

        let theme = IFPreferences.shared.getCurrentTheme()
        if theme.options.count > Int(IFSyntaxHighlightingOptionType.mainText.rawValue) {
            textColour = theme.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)].colour
        }

        return [.font: font,
                .foregroundColor: textColour]
    }

    private final func uneditablePartLength() -> Int {
        let name = self.name as NSString
        if depth <= 1 {
            return name.length
        }

        var x = 0
        var spaceCount = 0
        while x < name.length {
            if name.character(at: x) == unichar(UInt8(ascii: " ")) {
                spaceCount += 1
            }
            if spaceCount == 3 {
                break
            }
            x += 1
        }
        if x >= name.length {
            return x
        }

        // x is now the position of the 3rd space (which should correspond to the part of the string ' * Part ')
        return x + 1
    }

    private final var editableName: String {
        // Get the editable portion of the string
        var editable = (name as NSString).substring(from: uneditablePartLength()) as NSString
        if editable.length == 0 {
            return ""
        }

        // Strip off any trailing spaces
        if editable.character(at: editable.length - 1) == unichar(UInt8(ascii: "\n")) {
            editable = editable.substring(to: editable.length - 1) as NSString
        }

        // Return the result
        return editable as String
    }

    func freshValue(forEditedTitle edited: String) -> String {
        let uneditable = (name as NSString).substring(to: uneditablePartLength()) as NSString
        return uneditable.substring(from: (bulletPoint as NSString).length) + edited + "\n"
    }

    @objc(editing)
    var isEditing: Bool {
        @objc(isEditing) get {
            return _editing
        }
        set {
            _editing = newValue
        }
    }

    var textBackgroundColour: NSColor? {
        // Draw the node background, if necessary
        var nodeBackgroundColour: NSColor? = nil

        switch selectionStyle {
        case .selected:
            nodeBackgroundColour = NSColor.selectedTextBackgroundColor

        case .inputCursor:
            nodeBackgroundColour = NSColor.gray

        default:
            break
        }

        if let nodeBackgroundColour {
            // Pick the colours that we'll use to do the drawing
            let nodeTextBgColour = nodeBackgroundColour.withAlphaComponent(0.8)
            return nodeTextBgColour
        }

        return nil
    }

    var attributedTitle: NSAttributedString {
        let result = NSAttributedString(string: editableName,
                                        attributes: attributes)
        return result
    }

    private final var fullHeaderTitleRect: NSRect {
        let uneditablePortion = (name as NSString).substring(to: uneditablePartLength())
        let editablePortion = editableName

        let uneditableSize = (uneditablePortion as NSString).size(withAttributes: attributes)
        let nameSize = (editablePortion as NSString).size(withAttributes: attributes)
        return NSRect(x: _frame.origin.x + margin + CGFloat(depth) * indent + uneditableSize.width,
                      y: _frame.origin.y,
                      width: nameSize.width,
                      height: gap + font.ascender - font.descender)
    }

    var headerTitleRect: NSRect {
        let uneditablePortion = (name as NSString).substring(to: uneditablePartLength())
        let editablePortion = editableName

        let uneditableSize = (uneditablePortion as NSString).size(withAttributes: attributes)
        let nameSize = (editablePortion as NSString).size(withAttributes: attributes)
        return NSRect(x: _frame.origin.x + margin + CGFloat(depth) * indent + uneditableSize.width,
                      y: _frame.origin.y + floor(gap/2),
                      width: nameSize.width,
                      height: nameSize.height)
    }

    @objc(drawNodeInRect:withFrame:)
    func draw(in rect: NSRect,
              withFrame drawFrame: NSRect) {
        // Do nothing if this node is outside the draw rectangle
        if !NSIntersectsRect(rect, _frame) {
            return
        }

        // Draw the node background, if necessary
        var nodeBackgroundColour: NSColor? = nil

        switch selectionStyle {
        case .selected:
            nodeBackgroundColour = NSColor.selectedTextBackgroundColor

        case .inputCursor:
            nodeBackgroundColour = NSColor.gray

        default:
            break
        }

        if let nodeBackgroundColour {
            // Pick the colours that we'll use to do the drawing
            let nodeLineColour = nodeBackgroundColour
            let nodeTextBgColour = nodeBackgroundColour.withAlphaComponent(0.8)
            let nodeChildBgColour = nodeBackgroundColour.withAlphaComponent(0.2)

            // Create a bezier path representing this node
            let highlightPath = highlightPath(for: drawFrame)
            let textHighlightPath = truncatedHighlightPath(for: drawFrame)

            // Draw it
            nodeChildBgColour.set();    highlightPath.fill()
            nodeTextBgColour.set();     textHighlightPath.fill()
            nodeLineColour.set();       highlightPath.stroke()
        }

        // If editing, then only draw the uneditable part of the name
        let name: String
        if _editing {
            name = (self.name as NSString).substring(to: uneditablePartLength())
        } else {
            name = self.name
        }

        // Draw the node title, truncating if necessary
        (name as NSString).draw(at: NSPoint(x: _frame.origin.x + margin + CGFloat(depth) * indent,
                                            y: _frame.origin.y + floor(gap/2)),
                                withAttributes: attributes)

        // Draw the node children
        if let children = _children, children.count > 0 {
            var lastChild: IFHeaderNode? = nil

            for child in children {
                // Draw this child
                child.draw(in: rect,
                           withFrame: drawFrame)

                // Draw a line linking this child to the last child if possible
                if let lastChild, lastChild.children != nil, lastChild.selectionStyle == .unselected {
                    NSColor(deviceWhite: 0.8, alpha: 1.0).set()

                    var lineStart = lastChild.frame.origin
                    var lineEnd = child.frame.origin

                    lineStart.x += margin + 6 + CGFloat(depth + 1) * indent + 0.5
                    lineEnd.x   += margin + 6 + CGFloat(depth + 1) * indent + 0.5

                    lineStart.y += lastChild.font.ascender - lastChild.font.descender + gap - 1
                    lineEnd.y   += gap

                    NSBezierPath.strokeLine(from: lineStart,
                                            to: lineEnd)
                }

                // Move on
                lastChild = child
            }

            // Draw a line linking this child to the last child if possible
            if let lastChild, lastChild.children != nil, lastChild.selectionStyle == .unselected {
                NSColor(deviceWhite: 0.8, alpha: 1.0).set()

                let lastFrame = lastChild.frame
                var lineStart = lastFrame.origin
                var lineEnd = NSPoint(x: NSMinX(lastFrame), y: NSMaxY(lastFrame))

                lineStart.x += margin + 6 + CGFloat(depth + 1) * indent + 0.5
                lineEnd.x   += margin + 6 + CGFloat(depth + 1) * indent + 0.5

                lineStart.y += lastChild.font.ascender - lastChild.font.descender + gap - 1
                lineEnd.y   -= gap/2

                NSBezierPath.strokeLine(from: lineStart,
                                        to: lineEnd)
            }
        }
    }
}
