//
//  IFHeaderNodeTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFHeaderNodeTests: XCTestCase, @unchecked Sendable {

    // MARK: - Headings

    private func heading(_ name: String, level: Int32) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// A file with each heading on the line given, counted from 0, as `IFIntelFile` counts them
    private func file(_ headings: [(String, Int32, Int32)]) -> IFIntelFile {
        let file = IFIntelFile()
        for (name, level, line) in headings {
            file.add(heading(name, level: level), atLine: line)
        }
        return file
    }

    /// A story's title and headings, each heading a paragraph of its own, as Inform needs, and with its line's
    /// newline, as the highlighter gives it
    private let story: [(String, Int32, Int32)] = [
        ("The Story", 0, 0),
        ("Part One - The Beginning\n", 3, 2),
        ("Chapter 1 - Arrival\n", 4, 4),
        ("Chapter 2 - A Heading Much Wider Than Any Of The Others\n", 4, 8),
        ("Part Two - The End\n", 3, 12),
        ("Section A\n", 5, 14),
    ]

    /// The root node of a file's headers, laid out as the header view lays it out, to the depth given
    private func rootNode(depth: Int32 = 6, file: IFIntelFile? = nil) -> IFHeaderNode {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file ?? self.file(story))
        let root = IFHeaderNode(header: controller.rootHeader!, position: .zero, depth: 0)
        root.populate(toDepth: depth)
        return root
    }

    /// A node's heading, without its newline
    private func name(_ node: IFHeaderNode?) -> String? {
        guard let node else {
            return nil
        }
        return node.header.headingName.trimmingCharacters(in: .newlines)
    }

    /// The node at or below the one given whose heading starts with the text given
    private func node(_ prefix: String, in node: IFHeaderNode) -> IFHeaderNode? {
        if node.header.headingName.hasPrefix(prefix) {
            return node
        }
        for child in node.children ?? [] {
            if let found = self.node(prefix, in: child) {
                return found
            }
        }
        return nil
    }

    /// A node and those below it, with each one's children in brackets
    private func outline(_ node: IFHeaderNode) -> String {
        guard let children = node.children else {
            return name(node)!
        }
        return name(node)! + " (" + children.map { outline($0) }.joined(separator: ", ") + ")"
    }

    /// A node and those below it, in order
    private func flattened(_ node: IFHeaderNode) -> [IFHeaderNode] {
        return [node] + (node.children ?? []).flatMap { flattened($0) }
    }

    private var contents: String { IFUtility.localizedString("HeaderPage") }

    // MARK: - Layout

    private func layout(_ key: String) -> CGFloat {
        return CGFloat(UserDefaults.standard.double(forKey: key))
    }

    private var margin: CGFloat { layout("IFHeaderMargin") }
    private var indent: CGFloat { layout("IFHeaderIndent") }
    private var gap: CGFloat { layout("IFHeaderGap") }
    private var corner: CGFloat { layout("IFHeaderCorner") }
    private var pointSize: CGFloat { layout("IFHeaderPointSize") }

    private func font(_ node: IFHeaderNode) -> NSFont {
        return node.attributes[.font] as! NSFont
    }

    /// The height of a node's own line
    private func rowHeight(_ node: IFHeaderNode) -> CGFloat {
        return gap + font(node).ascender - font(node).descender
    }

    private func width(_ text: String, _ node: IFHeaderNode) -> CGFloat {
        return (text as NSString).size(withAttributes: node.attributes).width
    }

    private func rgba(_ colour: NSColor?) -> [CGFloat]? {
        guard let colour = colour?.usingColorSpace(.sRGB) else {
            return nil
        }
        return [colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent]
    }

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            // The first node registers the layout's defaults
            _ = IFHeaderNode(header: IFHeader(name: "", parent: nil, children: nil), position: .zero, depth: 0)
        }
    }

    // MARK: - Constructing nodes

    func testTheLayoutsDefaults() {
        let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        XCTAssertEqual(registered["IFHeaderPointSize"] as? Double, Double(NSFont.smallSystemFontSize))
        XCTAssertEqual(registered["IFHeaderMargin"] as? Double, 5)
        XCTAssertEqual(registered["IFHeaderIndent"] as? Double, 12)
        XCTAssertEqual(registered["IFHeaderGap"] as? Double, 8)
        XCTAssertEqual(registered["IFHeaderCorner"] as? Double, 5)
    }

    func testANodeOnItsOwn() {
        let header = IFHeader(name: "Part One - The Beginning\n", parent: nil, children: nil)
        let node = IFHeaderNode(header: header, position: NSPoint(x: 3, y: 7), depth: 2)

        XCTAssertIdentical(node.header, header)
        XCTAssertEqual(node.selectionStyle, .unselected)
        XCTAssertFalse(node.isEditing)
        XCTAssertNil(node.children)
        // It isn't laid out until it's populated
        XCTAssertEqual(node.frame, .zero)

        node.populate(toDepth: 6)
        XCTAssertNil(node.children)
        // A heading below the top has a bullet in front of it
        XCTAssertEqual(node.frame, NSRect(x: 3, y: 7,
                                          width: width(" • Part One - The Beginning\n", node),
                                          height: rowHeight(node)))
    }

    func testTheTopNodeHasNoBullet() {
        let root = rootNode(depth: 0)
        XCTAssertEqual(root.frame, NSRect(x: 0, y: 0, width: width(contents, root), height: rowHeight(root)))
    }

    func testTheNodesBelowANode() {
        XCTAssertEqual(outline(rootNode(depth: 6)),
                       "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, "
                       + "Chapter 2 - A Heading Much Wider Than Any Of The Others), Part Two - The End (Section A)))")
        XCTAssertEqual(outline(rootNode(depth: 5)),
                       "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, "
                       + "Chapter 2 - A Heading Much Wider Than Any Of The Others), Part Two - The End (Section A)))")
        XCTAssertEqual(outline(rootNode(depth: 4)),
                       "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, "
                       + "Chapter 2 - A Heading Much Wider Than Any Of The Others), Part Two - The End))")
        XCTAssertEqual(outline(rootNode(depth: 3)),
                       "\(contents) (The Story (Part One - The Beginning, Part Two - The End))")
        XCTAssertEqual(outline(rootNode(depth: 1)), "\(contents) (The Story)")
        XCTAssertEqual(outline(rootNode(depth: 0)), contents)
    }

    /// Each node's line is below the one before it, and a node's frame takes in its children's
    func testNodesAreLaidOutOneBelowAnother() {
        let root = rootNode()
        let nodes = flattened(root)
        XCTAssertEqual(nodes.count, 7)

        var y: CGFloat = 0
        for node in nodes {
            XCTAssertEqual(node.frame.minX, 0, name(node)!)
            XCTAssertEqual(node.frame.minY, y, name(node)!)
            y = floor(y + rowHeight(node))
        }

        for node in nodes {
            guard let children = node.children else {
                XCTAssertEqual(node.frame.height, rowHeight(node), name(node)!)
                continue
            }
            XCTAssertEqual(node.frame.maxY, children.last!.frame.maxY, accuracy: 0.001, name(node)!)
        }
    }

    /// A node's frame takes in its children's headings, which are indented further than its own
    func testANodeIsWideEnoughForItsChildren() {
        let root = rootNode()
        for node in flattened(root) {
            guard let children = node.children else {
                continue
            }
            // The top node's heading has no bullet
            let own = width((node === root ? "" : " • ") + node.header.headingName, node)
            let widest = children.map { $0.frame.maxX + indent }.max()!
            XCTAssertEqual(node.frame.width, max(own, widest) - node.frame.minX, name(node)!)
        }
    }

    // MARK: - How a node looks

    func testFonts() {
        let root = rootNode()
        let part = node("Part One", in: root)!
        let regular = NSFont.systemFont(ofSize: pointSize)
        let bold = NSFont.boldSystemFont(ofSize: pointSize)

        // The top node is always bold
        XCTAssertEqual(font(root), bold)
        root.selectionStyle = .inputCursor
        XCTAssertEqual(font(root), bold)

        // The others are bold when selected
        XCTAssertEqual(font(part), regular)
        part.selectionStyle = .selected
        XCTAssertEqual(font(part), bold)
        part.selectionStyle = .inputCursor
        XCTAssertEqual(font(part), regular)
    }

    func testTheTextIsTheColourOfTheThemesMainText() {
        let theme = IFPreferences.shared.getCurrentTheme()
        let mainText = theme.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)].colour
        let root = rootNode()
        XCTAssertEqual(root.attributes[.foregroundColor] as? NSColor, mainText)
        XCTAssertEqual(node("Chapter 1", in: root)!.attributes[.foregroundColor] as? NSColor, mainText)
    }

    func testTheBackgroundOfTheText() {
        let part = node("Part One", in: rootNode())!
        XCTAssertNil(part.textBackgroundColour)

        part.selectionStyle = .selected
        XCTAssertEqual(rgba(part.textBackgroundColour),
                       rgba(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.8)))

        part.selectionStyle = .inputCursor
        XCTAssertEqual(rgba(part.textBackgroundColour), rgba(NSColor.gray.withAlphaComponent(0.8)))

        part.selectionStyle = .unselected
        XCTAssertNil(part.textBackgroundColour)
    }

    // MARK: - Editing a heading

    /// What follows the first word of a heading can be edited, but not the headers above the headings
    func testWhatCanBeEdited() {
        let root = rootNode()
        let part = node("Part One", in: root)!
        XCTAssertEqual(part.attributedTitle.string, "One - The Beginning")
        XCTAssertEqual(part.attributedTitle.attributes(at: 0, effectiveRange: nil) as NSDictionary,
                       part.attributes as NSDictionary)
        XCTAssertEqual(node("Chapter 1", in: root)!.attributedTitle.string, "1 - Arrival")
        XCTAssertEqual(node("Section A", in: root)!.attributedTitle.string, "A")

        XCTAssertEqual(node("The Story", in: root)!.attributedTitle.string, "")
        XCTAssertEqual(root.attributedTitle.string, "")

        // A heading's name without a newline
        let header = IFHeader(name: "Part Three", parent: nil, children: nil)
        XCTAssertEqual(IFHeaderNode(header: header, position: .zero, depth: 2).attributedTitle.string, "Three")
    }

    /// An edited heading is given back as its line in the source, with the heading's first word
    func testAnEditedTitleBecomesALineOfSource() {
        let root = rootNode()
        XCTAssertEqual(node("Part One", in: root)!.freshValue(forEditedTitle: "Two - The Middle"),
                       "Part Two - The Middle\n")
        XCTAssertEqual(node("Chapter 1", in: root)!.freshValue(forEditedTitle: "3 - Departure"),
                       "Chapter 3 - Departure\n")
        XCTAssertEqual(node("Section A", in: root)!.freshValue(forEditedTitle: "B"), "Section B\n")
    }

    func testWhereTheTitleIsEdited() {
        let root = rootNode()
        let chapter = node("Chapter 1", in: root)!
        let uneditable = (" • Chapter " as NSString).size(withAttributes: chapter.attributes)
        let editable = ("1 - Arrival" as NSString).size(withAttributes: chapter.attributes)

        XCTAssertEqual(chapter.headerTitleRect,
                       NSRect(x: chapter.frame.minX + margin + 3 * indent + uneditable.width,
                              y: chapter.frame.minY + floor(gap / 2),
                              width: editable.width,
                              height: editable.height))
    }

    func testEditing() {
        let part = node("Part One", in: rootNode())!
        part.isEditing = true
        XCTAssertTrue(part.isEditing)
        part.isEditing = false
        XCTAssertFalse(part.isEditing)
    }

    // MARK: - Finding nodes

    func testClickingANode() {
        let root = rootNode()
        let story = node("The Story", in: root)!
        let part = node("Part One", in: root)!
        let chapter = node("Chapter 1", in: root)!
        var editable = false

        // The part of its heading that can be edited
        let title = part.headerTitleRect
        XCTAssertIdentical(root.atPoint(NSPoint(x: title.minX + 1, y: title.midY), editableOut: &editable), part)
        XCTAssertTrue(editable)

        // Its bullet and first word
        XCTAssertIdentical(root.atPoint(NSPoint(x: margin + 2 * indent + 1, y: title.midY),
                                     editableOut: &editable), part)
        XCTAssertFalse(editable)

        // The headers above the headings
        editable = true
        XCTAssertIdentical(root.atPoint(NSPoint(x: margin + indent + 1, y: story.frame.minY + rowHeight(story) / 2),
                                     editableOut: &editable), story)
        XCTAssertFalse(editable)
        editable = true
        XCTAssertIdentical(root.atPoint(NSPoint(x: margin + 1, y: root.frame.minY + 1), editableOut: &editable),
                           root)
        XCTAssertFalse(editable)

        // A chapter's heading
        let chapterTitle = chapter.headerTitleRect
        XCTAssertIdentical(root.atPoint(NSPoint(x: chapterTitle.midX, y: chapterTitle.midY),
                                     editableOut: &editable), chapter)
        XCTAssertTrue(editable)

        // Not the margin, nor the indentation in front of a heading
        editable = true
        XCTAssertNil(root.atPoint(NSPoint(x: margin - 1, y: title.midY), editableOut: &editable))
        XCTAssertFalse(editable)
        editable = true
        XCTAssertNil(root.atPoint(NSPoint(x: margin + 2 * indent + 1, y: chapterTitle.midY), editableOut: &editable))
        XCTAssertFalse(editable)

        // Nor below the headings
        editable = true
        XCTAssertNil(root.atPoint(NSPoint(x: margin + 1, y: root.frame.maxY + 1), editableOut: &editable))
        XCTAssertFalse(editable)
    }

    /// The end of the widest heading, which is indented further than the headings it's below, can be clicked
    func testTheEndOfTheWidestHeadingCanBeClicked() {
        let root = rootNode()
        let chapter = node("Chapter 2", in: root)!
        for node in flattened(root) where node !== chapter {
            XCTAssertLessThan(width(node.header.headingName, node), width(chapter.header.headingName, chapter),
                              name(node)!)
        }

        let title = chapter.headerTitleRect
        var editable = false
        XCTAssertIdentical(root.atPoint(NSPoint(x: title.maxX - 1, y: title.midY), editableOut: &editable), chapter)
        XCTAssertTrue(editable)
    }

    /// The source page asks for the node for the lines it shows, counting them from 1, as `IFIntelFile` counts
    /// them from 0, so showing a heading's section starts one line later than the heading's line in the file
    func testTheNodeForTheLinesShown() {
        let file = file(story)
        let root = rootNode(file: file)

        func found(_ location: Int, length: Int = 1, in root: IFHeaderNode? = nil) -> String? {
            return name((root ?? rootNode(file: file)).withLines(NSRange(location: location, length: length),
                                                            intelFile: file))
        }

        XCTAssertEqual(found(0, in: root), "The Story")
        XCTAssertEqual(found(1, in: root), "The Story")
        XCTAssertEqual(found(3, in: root), "Part One - The Beginning")
        XCTAssertEqual(found(5, in: root), "Chapter 1 - Arrival")
        XCTAssertEqual(found(8, in: root), "Chapter 1 - Arrival")
        XCTAssertEqual(found(9, in: root), "Chapter 2 - A Heading Much Wider Than Any Of The Others")
        XCTAssertEqual(found(9, length: 10, in: root), "Chapter 2 - A Heading Much Wider Than Any Of The Others")
        XCTAssertEqual(found(13, in: root), "Part Two - The End")
        XCTAssertEqual(found(15, in: root), "Section A")
        XCTAssertEqual(found(40, in: root), "Section A")

        // A heading that isn't shown is in the section of the one above it that is
        XCTAssertEqual(found(5, in: rootNode(depth: 3, file: file)), "Part One - The Beginning")
        XCTAssertEqual(found(15, in: rootNode(depth: 4, file: file)), "Part Two - The End")

        // Headings that aren't in the file are never found
        XCTAssertEqual(name(root.withLines(NSRange(location: 5, length: 1), intelFile: self.file(story))),
                       "The Story")
    }

    // MARK: - Drawing

    /// What a node draws in a view of the size given, flipped as the header view is
    private func draw(_ node: IFHeaderNode, size: NSSize, in rect: NSRect? = nil) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
        context.clear(CGRect(origin: .zero, size: size))
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        let bounds = NSRect(origin: .zero, size: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        node.draw(in: rect ?? bounds, withFrame: bounds)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    /// Whether anything was drawn in a rectangle
    private func isDrawn(_ bitmap: NSBitmapImageRep, in rect: NSRect) -> Bool {
        for y in Int(rect.minY.rounded(.up))..<Int(rect.maxY.rounded(.down)) {
            for x in Int(rect.minX.rounded(.up))..<Int(rect.maxX.rounded(.down)) {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
                    return true
                }
            }
        }
        return false
    }

    private func size(_ root: IFHeaderNode) -> NSSize {
        return NSSize(width: 600, height: ceil(root.frame.maxY) + 5)
    }

    func testANodeIsDrawnOnlyInTheRectangleGiven() {
        let root = rootNode()
        let title = node("Part One", in: root)!.headerTitleRect

        XCTAssertTrue(isDrawn(draw(root, size: size(root)), in: title))

        let below = NSRect(x: 0, y: ceil(root.frame.maxY) + 1, width: 600, height: 4)
        let bitmap = draw(root, size: size(root), in: below)
        XCTAssertFalse(isDrawn(bitmap, in: NSRect(origin: .zero, size: size(root))))
    }

    /// While a heading is edited, the field editor shows the part that can be edited, so the node doesn't
    func testAnEditedNodeShowsOnlyWhatCantBeEdited() {
        let root = rootNode()
        let part = node("Part One", in: root)!
        let title = part.headerTitleRect
        let firstWord = NSRect(x: margin + 2 * indent, y: title.minY, width: title.minX - margin - 2 * indent,
                               height: title.height)

        part.isEditing = true
        var bitmap = draw(root, size: size(root))
        XCTAssertTrue(isDrawn(bitmap, in: firstWord))
        XCTAssertFalse(isDrawn(bitmap, in: title))

        part.isEditing = false
        bitmap = draw(root, size: size(root))
        XCTAssertTrue(isDrawn(bitmap, in: firstWord))
        XCTAssertTrue(isDrawn(bitmap, in: title))
    }

    /// A selected node is highlighted across the view, and so are its children
    func testASelectedNodeIsHighlighted() {
        let root = rootNode()
        let part = node("Part One", in: root)!
        let chapter = node("Chapter 1", in: root)!
        let size = size(root)
        let rightOfRow = NSRect(x: size.width - margin - corner - 4, y: part.frame.minY + 3, width: 2, height: 2)
        let rightOfChild = NSRect(x: size.width - margin - corner - 4, y: chapter.frame.midY, width: 2, height: 2)

        XCTAssertFalse(isDrawn(draw(root, size: size), in: rightOfRow))
        XCTAssertFalse(isDrawn(draw(root, size: size), in: rightOfChild))

        part.selectionStyle = .selected
        XCTAssertTrue(isDrawn(draw(root, size: size), in: rightOfRow))
        XCTAssertTrue(isDrawn(draw(root, size: size), in: rightOfChild))

        part.selectionStyle = .inputCursor
        XCTAssertTrue(isDrawn(draw(root, size: size), in: rightOfRow))
    }

    /// A line joins a heading with children to the heading after it, or runs to the end of its children
    func testLinesJoinHeadingsWithChildren() {
        let root = rootNode()
        let chapter = node("Chapter 1", in: root)!
        let section = node("Section A", in: root)!
        let bitmap = draw(root, size: size(root))
        // The line is between the bullets of the parts and those of their children
        let x = Int(margin + 6 + 2 * indent)

        for (row, name) in [(chapter, "Chapter 1"), (section, "Section A")] {
            let colour = bitmap.colorAt(x: x, y: Int(row.frame.midY))
            XCTAssertEqual(colour?.alphaComponent ?? 0, 1, accuracy: 0.01, name)
            XCTAssertEqual(colour?.redComponent ?? 0, 0.8, accuracy: 0.01, name)
            XCTAssertEqual(colour?.greenComponent ?? 0, 0.8, accuracy: 0.01, name)
            XCTAssertEqual(colour?.blueComponent ?? 0, 0.8, accuracy: 0.01, name)
        }

        // Not when the parts' children aren't shown: between the text of the parts, where it would start
        let shallow = rootNode(depth: 3)
        let partOne = node("Part One", in: shallow)!
        let partTwo = node("Part Two", in: shallow)!
        let top = partOne.frame.minY + rowHeight(partOne) - 3
        let column = NSRect(x: CGFloat(x), y: top, width: 1, height: partTwo.frame.minY + 3 - top)
        XCTAssertFalse(isDrawn(draw(shallow, size: size(shallow)), in: column))
    }
}
