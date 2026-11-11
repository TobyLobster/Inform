//
//  IFHeaderPageTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, for preferences that are never written
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any] = [:]

    init() {
        super.init(suiteName: "IFHeaderPageTests.never-written")!
    }

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

/// A header page delegate that records what it's told
private final class RecordingDelegate: NSObject, IFHeaderPageDelegate {
    private(set) var limits: [(page: IFHeaderPage?, header: IFHeader)] = []
    private(set) var updates: [(view: IFHeaderView, node: IFHeaderNode, title: String)] = []
    private(set) var refreshes: [IFHeaderController] = []

    func headerPage(_ page: IFHeaderPage?, limitTo header: IFHeader) {
        limits.append((page, header))
    }

    func headerView(_ view: IFHeaderView, update node: IFHeaderNode, withNewTitle newTitle: String) {
        updates.append((view, node, newTitle))
    }

    func refreshHeaders(_ controller: IFHeaderController) {
        refreshes.append(controller)
    }
}

/// A header page delegate that wants to be told nothing
private final class QuietDelegate: NSObject, IFHeaderPageDelegate {
}

@MainActor
final class IFHeaderPageTests: XCTestCase {

    // MARK: - Headings

    private func heading(_ name: String, level: Int32) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// A file with each heading on the line given, counted from 0
    private func file(_ headings: [(String, Int32, Int32)]) -> IFIntelFile {
        let file = IFIntelFile()
        for (name, level, line) in headings {
            file.add(heading(name, level: level), atLine: line)
        }
        return file
    }

    /// A story's title and headings, with an example, each heading with its line's newline, as the highlighter gives it
    private let story: [(String, Int32, Int32)] = [
        ("The Story", 0, 0),
        ("Part One - The Beginning\n", 3, 2),
        ("Chapter 1 - Arrival\n", 4, 4),
        ("Chapter 2 - Departure\n", 4, 8),
        ("Part Two - The End\n", 3, 12),
        ("Section A\n", 5, 14),
        ("Example: * Locks\n", 6, 16),
    ]

    /// Another story
    private let otherStory: [(String, Int32, Int32)] = [
        ("Another Story", 0, 0),
        ("Book 1 - Elsewhere\n", 2, 2),
    ]

    /// A controller with a file's headers
    private func controller(_ headings: [(String, Int32, Int32)]? = nil) -> IFHeaderController {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(headings ?? story))
        return controller
    }

    /// A node's heading, without its newline
    private func name(_ node: IFHeaderNode) -> String {
        return node.header.headingName.trimmingCharacters(in: .newlines)
    }

    /// A node and those below it, with each one's children in brackets
    private func outline(_ node: IFHeaderNode) -> String {
        guard let children = node.children else {
            return name(node)
        }
        return name(node) + " (" + children.map { outline($0) }.joined(separator: ", ") + ")"
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

    /// The nodes at or below the one given
    private func nodes(_ node: IFHeaderNode) -> [IFHeaderNode] {
        return [node] + (node.children ?? []).flatMap { nodes($0) }
    }

    /// The headings of the nodes the page's view shows as selected
    private func selected(_ page: IFHeaderPage) -> [String] {
        return nodes(page.headerView.rootHeaderNode).filter { $0.selectionStyle == .selected }.map { name($0) }
    }

    private var contents: String { IFUtility.localizedString("HeaderPage") }
    private var margin: CGFloat { CGFloat(UserDefaults.standard.double(forKey: "IFHeaderMargin")) }
    private var indent: CGFloat { CGFloat(UserDefaults.standard.double(forKey: "IFHeaderIndent")) }

    private var storyOutline: String {
        return "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, Chapter 2 - Departure), "
            + "Part Two - The End (Section A (Example: * Locks))))"
    }

    // MARK: - The page

    /// A page for preferences kept in memory
    private func makePage() -> (IFHeaderPage, IFPreferences) {
        let preferences = IFPreferences(userDefaults: MemoryDefaults())
        return (IFHeaderPage(preferences: preferences), preferences)
    }

    private func depthButton(_ page: IFHeaderPage) throws -> NSPopUpButton {
        return try XCTUnwrap(page.value(forKey: "depthButton") as? NSPopUpButton)
    }

    private func scrollView(_ page: IFHeaderPage) throws -> NSScrollView {
        return try XCTUnwrap(page.value(forKey: "scrollView") as? NSScrollView)
    }

    /// Chooses a depth from the page's menu, as its user would
    private func chooseDepth(_ index: Int, on page: IFHeaderPage) throws {
        let button = try depthButton(page)
        button.selectItem(at: index)
        NSApp.sendAction(try XCTUnwrap(button.action), to: button.target, from: button)
    }

    /// Clicks a point in a view
    private func click(_ view: NSView, at point: NSPoint) {
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: view.convert(point, to: nil), modifierFlags: [],
                                       timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                                       eventNumber: 0, clickCount: 1, pressure: 1)!
        view.mouseDown(with: event)
    }

    // MARK: - A new page

    func testANewPage() throws {
        let (page, _) = makePage()
        let view = page.headerView

        // The view is in the page's view, in a scroll view
        XCTAssertTrue(view.isDescendant(of: page.pageView))
        XCTAssertIdentical(try scrollView(page).documentView, view)
        XCTAssertTrue(try scrollView(page).isDescendant(of: page.pageView))
        XCTAssertIdentical(view.delegate, page)
        XCTAssertNil(page.controller)
        XCTAssertNil(page.delegate)

        // The deepest level is chosen, and shown
        let button = try depthButton(page)
        XCTAssertEqual(button.numberOfItems, 5)
        XCTAssertEqual(button.indexOfSelectedItem, 4)
        XCTAssertEqual(view.displayDepth, 5)
        XCTAssertEqual(view.message, IFUtility.localizedString("NoHeadingsSet"))
    }

    /// The page shows the preferences' paper colour for extensions, behind the headings and around them
    func testColours() throws {
        let (page, preferences) = makePage()
        XCTAssertEqual(try scrollView(page).backgroundColor, preferences.extensionPaper.colour)
        XCTAssertEqual(page.headerView.backgroundColour, preferences.extensionPaper.colour)

        let red = NSColor(srgbRed: 0.8, green: 0.1, blue: 0.1, alpha: 1)
        preferences.extensionPaper = IFSyntaxColouringOption(colour: red)
        XCTAssertEqual(try scrollView(page).backgroundColor, red)
        XCTAssertEqual(page.headerView.backgroundColour, red)

        // Other preferences are no concern of the page's
        let other = IFPreferences(userDefaults: MemoryDefaults())
        other.extensionPaper = IFSyntaxColouringOption(colour: .blue)
        XCTAssertEqual(try scrollView(page).backgroundColor, red)
        XCTAssertEqual(page.headerView.backgroundColour, red)
    }

    // MARK: - The controller

    func testTheControllerGivesTheViewItsHeaders() {
        let (page, _) = makePage()
        let view = page.headerView
        let first = controller()
        page.controller = first
        XCTAssertIdentical(page.controller, first)
        XCTAssertNil(view.message)
        XCTAssertEqual(outline(view.rootHeaderNode), storyOutline)

        // New headers
        first.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(outline(view.rootHeaderNode), "\(contents) (Another Story (Book 1 - Elsewhere))")

        // Another controller
        let second = controller()
        page.controller = second
        XCTAssertEqual(outline(view.rootHeaderNode), storyOutline)
        first.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(outline(view.rootHeaderNode), storyOutline)

        // No controller
        page.controller = nil
        XCTAssertNil(page.controller)
        second.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(outline(view.rootHeaderNode), storyOutline)
    }

    /// A new header view takes the old one's place with the controller
    func testANewHeaderView() {
        let (page, _) = makePage()
        let oldView = page.headerView
        let controller = controller()
        page.controller = controller

        let newView = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        page.headerView = newView
        XCTAssertIdentical(page.headerView, newView)
        XCTAssertEqual(outline(newView.rootHeaderNode), storyOutline)

        controller.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(outline(newView.rootHeaderNode), "\(contents) (Another Story (Book 1 - Elsewhere))")
        XCTAssertEqual(outline(oldView.rootHeaderNode), storyOutline)
    }

    /// A page that goes takes its view away from the controller
    func testAPageThatGoesLeavesTheController() {
        let controller = controller()
        weak var weakPage: IFHeaderPage?
        var view: IFHeaderView?
        autoreleasepool {
            let (page, _) = makePage()
            page.controller = controller
            weakPage = page
            view = page.headerView
        }
        XCTAssertNil(weakPage)

        controller.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(outline(try XCTUnwrap(view).rootHeaderNode), storyOutline)
    }

    // MARK: - The depth menu

    func testTheDepthMenu() throws {
        let (page, _) = makePage()
        let view = page.headerView
        page.controller = controller()

        try chooseDepth(2, on: page)
        XCTAssertEqual(view.displayDepth, 3)
        XCTAssertEqual(outline(view.rootHeaderNode),
                       "\(contents) (The Story (Part One - The Beginning, Part Two - The End))")

        try chooseDepth(0, on: page)
        XCTAssertEqual(view.displayDepth, 1)
        XCTAssertEqual(outline(view.rootHeaderNode), "\(contents) (The Story)")

        // The deepest level shows examples too
        try chooseDepth(4, on: page)
        XCTAssertEqual(view.displayDepth, 5)
        XCTAssertEqual(outline(view.rootHeaderNode), storyOutline)
    }

    // MARK: - Highlighting

    /// The page starts with the lines (0, 0) highlighted, rather than none, and they're in the story's section, as the
    /// story's header stands for no symbol. It isn't seen, as the source page highlights the lines it shows as soon as
    /// it gives the page a controller.
    func testAtFirstTheStoryIsHighlighted() {
        let (page, _) = makePage()
        page.controller = controller()
        XCTAssertEqual(selected(page), ["The Story"])
    }

    /// The source page asks for the node for the lines it shows, counting them from 1
    func testHighlightingTheLinesShown() {
        let (page, _) = makePage()
        page.controller = controller()

        page.highlightNode(withLines: NSRange(location: 5, length: 1))
        XCTAssertEqual(selected(page), ["Chapter 1 - Arrival"])

        page.highlightNode(withLines: NSRange(location: 13, length: 3))
        XCTAssertEqual(selected(page), ["Part Two - The End"])

        page.highlightNode(withLines: NSRange(location: 1, length: 1))
        XCTAssertEqual(selected(page), ["The Story"])
        page.highlightNode(withLines: NSRange(location: 0, length: 0))
        XCTAssertEqual(selected(page), ["The Story"])
    }

    /// The top header is never highlighted, though it's the node for any lines when there are no headers
    func testHighlightingWithNoHeaders() {
        let (page, _) = makePage()
        page.highlightNode(withLines: NSRange(location: 5, length: 1))
        XCTAssertNil(page.headerView.rootHeaderNode.children)
        XCTAssertEqual(page.headerView.rootHeaderNode.selectionStyle, .unselected)
    }

    /// The lines shown stay highlighted when the headers are made again
    func testTheHighlightFollowsTheHeaders() throws {
        let (page, _) = makePage()
        let controller = controller()
        page.controller = controller
        page.highlightNode(withLines: NSRange(location: 5, length: 1))

        // New headers
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(selected(page), ["Chapter 1 - Arrival"])

        // Another depth, where the lines are in the part's section
        try chooseDepth(2, on: page)
        XCTAssertEqual(selected(page), ["Part One - The Beginning"])
        try chooseDepth(4, on: page)
        XCTAssertEqual(selected(page), ["Chapter 1 - Arrival"])

        // Another controller
        page.controller = self.controller()
        XCTAssertEqual(selected(page), ["Chapter 1 - Arrival"])
    }

    func testSelectingANode() throws {
        let (page, _) = makePage()
        let controller = controller()
        page.controller = controller
        let root = page.headerView.rootHeaderNode
        let part = try XCTUnwrap(node("Part One", in: root))
        let chapter = try XCTUnwrap(node("Chapter 2", in: root))

        page.select(part)
        XCTAssertEqual(selected(page), ["Part One - The Beginning"])
        page.select(chapter)
        XCTAssertEqual(selected(page), ["Chapter 2 - Departure"])
        page.select(chapter)
        XCTAssertEqual(selected(page), ["Chapter 2 - Departure"])
        page.select(nil)
        XCTAssertEqual(selected(page), [])

        // Selecting nothing forgets the lines that were highlighted
        page.highlightNode(withLines: NSRange(location: 5, length: 1))
        page.select(nil)
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(selected(page), [])
    }

    // MARK: - The delegate

    /// Clicking a heading asks the delegate to show only its section
    func testClickingAHeading() throws {
        let (page, _) = makePage()
        let view = page.headerView
        page.controller = controller()
        let delegate = RecordingDelegate()
        page.delegate = delegate
        XCTAssertIdentical(page.delegate, delegate)

        // A part's bullet and first word, which can't be edited
        let part = try XCTUnwrap(node("Part One", in: view.rootHeaderNode))
        click(view, at: NSPoint(x: margin + 2 * indent + 1, y: part.headerTitleRect.midY))
        XCTAssertEqual(delegate.limits.count, 1)
        XCTAssertIdentical(delegate.limits.first?.page, page)
        XCTAssertIdentical(delegate.limits.first?.header, part.header)

        let quiet = QuietDelegate()
        page.delegate = quiet
        click(view, at: NSPoint(x: margin + 2 * indent + 1, y: part.headerTitleRect.midY))
        XCTAssertEqual(delegate.limits.count, 1)
    }

    /// An edited heading is passed on to the delegate, as the view gives it
    func testEditingAHeading() throws {
        let (page, _) = makePage()
        let view = page.headerView
        page.controller = controller()
        let delegate = RecordingDelegate()
        page.delegate = delegate
        let part = try XCTUnwrap(node("Part One", in: view.rootHeaderNode))

        page.headerView(view, update: part, withNewTitle: "Part One - The Start\n")
        XCTAssertEqual(delegate.updates.count, 1)
        XCTAssertIdentical(delegate.updates.first?.view, view)
        XCTAssertIdentical(delegate.updates.first?.node, part)
        XCTAssertEqual(delegate.updates.first?.title, "Part One - The Start\n")

        let quiet = QuietDelegate()
        page.delegate = quiet
        page.headerView(view, update: part, withNewTitle: "Part One - The Start\n")
        XCTAssertEqual(delegate.updates.count, 1)
    }

    /// New headers are passed on to the delegate
    func testNewHeaders() {
        let (page, _) = makePage()
        let delegate = RecordingDelegate()
        page.delegate = delegate
        let controller = controller()
        page.controller = controller
        XCTAssertEqual(delegate.refreshes.count, 1)
        XCTAssertIdentical(delegate.refreshes.first, controller)

        controller.update(fromIntelligence: file(otherStory))
        XCTAssertEqual(delegate.refreshes.count, 2)

        let quiet = QuietDelegate()
        page.delegate = quiet
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(delegate.refreshes.count, 2)
    }
}
