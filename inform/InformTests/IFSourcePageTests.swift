//
//  IFSourcePageTests.swift
//  InformTests
//

import XCTest

/// A project controller with no window, whose document is the project the test gives it, and whose source highlights
/// are the ones the test gives it
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which the page shows the source of
    var project: IFProject?
    /// The highlights the page is given for any file
    var highlights: [[NSNumber]] = []
    /// The files the page has asked for the highlights of
    private(set) var highlightsAskedFor: [String?] = []

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }

    override func highlights(forFile file: String?) -> [[NSNumber]]? {
        highlightsAskedFor.append(file)
        return highlights
    }
}

/// The source page: the project's source files, a section of one at a time if wanted, and its headings
final class IFSourcePageTests: XCTestCase {

    /// A story with a section inside its first chapter, on lines 3, 7 and 11 of the text, counting from 1
    private let story = """
        "Story" by Me

        Chapter 1 - Hall

        The Hall is a room.

        Section 1 - Cupboard

        The Cupboard is a container.

        Chapter 2 - Yard

        The Yard is a room.

        """

    private let chapter1 = "Chapter 1 - Hall\n\nThe Hall is a room.\n\nSection 1 - Cupboard\n\nThe Cupboard is a container."
    private let section1 = "Section 1 - Cupboard\n\nThe Cupboard is a container."
    private let chapter2 = "Chapter 2 - Yard\n\nThe Yard is a room.\n"

    private let notes = "Remember the lamp.\n"

    private var folder: URL!
    private var controller: ProjectControllerStandIn!
    private var project: IFProject!
    private var window: NSWindow!
    private var page: IFSourcePage!
    private var textView: IFSourceFileView!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // A project with the story and some notes
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = folder.appendingPathComponent("Test.inform/Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data(story.utf8).write(to: source.appendingPathComponent("story.ni"))
        try Data(notes.utf8).write(to: source.appendingPathComponent("Notes.txt"))
        project = try IFProject(contentsOf: folder.appendingPathComponent("Test.inform"),
                                ofType: "org.inform-fiction.project")

        // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
        // toolbar for them, which saves its configuration in the user's preferences. Nor does it hear of the
        // headings changing, so it's told of them.
        controller = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(controller as Any)
        controller.project = project

        page = IFSourcePage(projectController: controller)
        controller.headerController.update(fromIntelligence: page.currentIntelligence)

        // In a window, for the animations. NSWindow moves a window made off the screen onto it, so it's moved off
        // afterwards
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        let content = try XCTUnwrap(window.contentView)
        page.view.frame = content.bounds
        content.addSubview(page.view)

        textView = try XCTUnwrap((page.view.subviews.first as? NSScrollView)?.documentView as? IFSourceFileView)
    }

    override func tearDownWithError() throws {
        waitForAnimations()
        window?.close()
        window = nil
        textView = nil
        page = nil
        project?.close()
        project = nil
        controller = nil
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private var undo: UndoManager {
        get throws {
            return try XCTUnwrap(project.undoManager)
        }
    }

    /// The story's text storage, which a section is shown from
    private var storage: NSTextStorage {
        get throws {
            return try XCTUnwrap(project.storage(forFile: "story.ni"))
        }
    }

    private func sourcePath(_ file: String) -> String {
        return folder.appendingPathComponent("Test.inform/Source/\(file)").path
    }

    private func range(of find: String, in text: String? = nil) -> NSRange {
        return ((text ?? story) as NSString).range(of: find)
    }

    private func location(of find: String) -> Int {
        return range(of: find).location
    }

    /// The range of some text in what's shown
    private func shownRange(of find: String) -> NSRange {
        return (textView.string as NSString).range(of: find)
    }

    /// Puts the insertion point before some text in the story
    private func putCursor(before find: String) {
        textView.setSelectedRange(NSRange(location: location(of: find), length: 0))
    }

    /// Whether the text view is torn at the top and bottom, from where it puts its text
    private var tears: (top: Bool, bottom: Bool) {
        let top = floor(NSImage(named: "App/TornPages/torn_top")?.size.height ?? 0)
        let bottom = floor(NSImage(named: "App/TornPages/torn_bottom")?.size.height ?? 0)
        let tornAtTop = textView.textContainerOrigin.y > 6
        let tornAtBottom = textView.textContainerInset.height == floor((6 + (tornAtTop ? top : 0) + bottom) / 2)
        return (tornAtTop, tornAtBottom)
    }

    private var isRestricted: Bool {
        get throws {
            return IFSyntaxManager.isRestricted(try storage, for: textView)
        }
    }

    /// The highlight behind a character of what's shown
    private func background(at index: Int) -> NSColor? {
        return textView.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: index,
                                                          effectiveRange: nil) as? NSColor
    }

    private func heading(_ name: String) throws -> IFIntelSymbol {
        var symbol = page.currentIntelligence?.firstSymbol
        while let heading = symbol {
            if heading.name?.hasPrefix(name) == true { return heading }
            symbol = heading.next
        }
        return try XCTUnwrap(nil, "No heading \(name)")
    }

    private func hasAnimator(_ view: NSView) -> Bool {
        return view is IFViewAnimator || view.subviews.contains { hasAnimator($0) }
    }

    /// Waits for any animation to finish, and for the message it sends then, after a delay of nothing
    private func waitForAnimations() {
        guard let content = window?.contentView else { return }
        let limit = Date(timeIntervalSinceNow: 2.0)
        while hasAnimator(content) && Date() < limit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertFalse(hasAnimator(content), "The animation didn't finish")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private var cellStates: [NSControl.StateValue] {
        return page.toolbarCells.map { $0.state }
    }

    // MARK: - The page

    func testTheTitle() {
        XCTAssertEqual(page.title, IFUtility.localizedString("Source Page Title", default: "Source"))
    }

    func testTheSourceAndHeadingsCells() {
        XCTAssertEqual(page.toolbarCells.map { $0.stringValue },
                       [IFUtility.localizedString("SourcePage", default: "Source"),
                        IFUtility.localizedString("HeaderPage", default: "Headings")])
        XCTAssertEqual(cellStates, [.on, .off])
    }

    func testTheSourcePapersColour() {
        XCTAssertEqual(textView.backgroundColor, IFPreferences.shared.sourcePaper.colour)
    }

    // MARK: - The source file shown

    func testShowsTheMainSourceFile() throws {
        XCTAssertEqual(textView.string, story)
        XCTAssertEqual(page.openSourceFilepath, "story.ni")
        XCTAssertEqual(page.currentFile, sourcePath("story.ni"))
        XCTAssertIdentical(page.currentIntelligence, IFSyntaxManager.intelligenceData(for: try storage))
    }

    func testShowsAnotherSourceFile() {
        page.showSourceFile("Notes.txt")
        XCTAssertEqual(textView.string, notes)
        // In full, once another file has been shown
        XCTAssertEqual(page.openSourceFilepath, sourcePath("Notes.txt"))
        XCTAssertEqual(page.currentFile, sourcePath("Notes.txt"))

        page.showSourceFile("story.ni")
        XCTAssertEqual(textView.string, story)
        XCTAssertEqual(page.openSourceFilepath, sourcePath("story.ni"))
    }

    func testShowingTheSameFileNoFileOrOneThatIsntThereChangesNothing() {
        textView.setSelectedRange(NSRange(location: 5, length: 2))
        page.showSourceFile("story.ni")
        page.showSourceFile(nil)
        page.showSourceFile("Missing.txt")
        XCTAssertEqual(textView.string, story)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 2))
        XCTAssertEqual(page.openSourceFilepath, "story.ni")
    }

    // MARK: - Moving and selecting

    func testMovesToALine() {
        page.move(toLine: 5)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: location(of: "The Hall"), length: 0))
        page.move(toLine: 5, character: 4)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: location(of: "Hall is"), length: 0))
        page.move(toLocation: 20)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 20, length: 0))
    }

    func testSelectsARange() {
        page.select(NSRange(location: 15, length: 9))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 15, length: 9))
    }

    func testFindsALineWithItsEnding() {
        XCTAssertEqual(page.findLine(3), NSRange(location: location(of: "Chapter 1"), length: 17))
    }

    func testIndicatesARangeOrALine() {
        let hall = range(of: "The Hall is a room.")
        page.indicateRange(hall)
        XCTAssertEqual(textView.selectedRange(), hall)
        page.indicateLine(9)
        XCTAssertEqual(textView.selectedRange(), range(of: "The Cupboard is a container."))
    }

    // MARK: - Pasting

    func testPastesSourceCodeOverTheSelection() throws {
        let hall = range(of: "The Hall")
        textView.setSelectedRange(hall)

        try undo.beginUndoGrouping()
        page.pasteSourceCode("The Great Hall")
        try undo.endUndoGrouping()
        XCTAssertEqual(try storage.string, story.replacingOccurrences(of: "The Hall is", with: "The Great Hall is"))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: hall.location, length: 14))

        try undo.undo()
        XCTAssertEqual(try storage.string, story)
        XCTAssertEqual(textView.selectedRange(), hall)
    }

    // MARK: - Showing one section

    func testShowsTheCurrentSectionOnly() throws {
        textView.setSelectedRange(NSRange(location: location(of: "Cupboard is"), length: 8))
        page.showCurrentSectionOnly(nil)
        XCTAssertEqual(textView.string, section1)
        XCTAssertTrue(try isRestricted)
        XCTAssertTrue(tears.top)
        XCTAssertTrue(tears.bottom)
        // The selection stays on the same text
        XCTAssertEqual(textView.selectedRange(), NSRange(location: shownRange(of: "Cupboard is").location, length: 8))
    }

    func testTheLastSectionIsntTornAtTheBottom() {
        putCursor(before: "Yard is")
        page.showCurrentSectionOnly(nil)
        XCTAssertEqual(textView.string, chapter2)
        XCTAssertTrue(tears.top)
        XCTAssertFalse(tears.bottom)
    }

    func testShowsFewerAndMoreHeadings() throws {
        putCursor(before: "Cupboard is")
        page.showFewerHeadings(nil)
        XCTAssertEqual(textView.string, chapter1)
        page.showFewerHeadings(nil)
        XCTAssertEqual(textView.string, section1)
        // None fewer
        page.showFewerHeadings(nil)
        XCTAssertEqual(textView.string, section1)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: shownRange(of: "Cupboard is").location, length: 0))

        page.showMoreHeadings(nil)
        XCTAssertEqual(textView.string, chapter1)
        // Then the whole story, which is still a restriction, to all of it
        page.showMoreHeadings(nil)
        XCTAssertEqual(textView.string, story)
        XCTAssertTrue(try isRestricted)
        XCTAssertFalse(tears.top)
        XCTAssertFalse(tears.bottom)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: location(of: "Cupboard is"), length: 0))
    }

    func testShowsTheEntireSource() throws {
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        page.showEntireSource(nil)
        XCTAssertEqual(textView.string, story)
        XCTAssertFalse(tears.top)
        XCTAssertFalse(tears.bottom)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: location(of: "Hall is"), length: 0))
    }

    func testShowsTheNextAndPreviousSections() throws {
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        XCTAssertEqual(textView.string, chapter1)

        page.sourceFileShowNextSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, chapter2)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        // None after the last
        page.sourceFileShowNextSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, chapter2)

        page.sourceFileShowPreviousSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, chapter1)
        // Before the first chapter, the whole story
        page.sourceFileShowPreviousSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, story)
        XCTAssertFalse(try isRestricted)
        XCTAssertFalse(tears.top)
        XCTAssertFalse(tears.bottom)
    }

    func testShowsTheSectionAfterTheLastInAChapter() {
        putCursor(before: "Cupboard is")
        page.showCurrentSectionOnly(nil)
        page.sourceFileShowNextSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, chapter2)
        page.sourceFileShowPreviousSection(nil)
        waitForAnimations()
        XCTAssertEqual(textView.string, chapter1)
    }

    func testIndicatesARangeInTheSectionShown() {
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        page.indicateRange(range(of: "The Cupboard"))
        XCTAssertEqual(textView.string, chapter1)
        XCTAssertEqual(textView.selectedRange(), shownRange(of: "The Cupboard"))
    }

    func testIndicatingARangeInAnotherSectionShowsThatSection() {
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        page.indicateRange(range(of: "The Yard"))
        XCTAssertEqual(textView.string, chapter2)
        XCTAssertEqual(textView.selectedRange(), shownRange(of: "The Yard"))
    }

    func testShowingASectionCanBeUndone() throws {
        try undo.beginUndoGrouping()
        putCursor(before: "Cupboard is")
        page.showCurrentSectionOnly(nil)
        try undo.endUndoGrouping()

        try undo.undo()
        XCTAssertEqual(textView.string, story)
        XCTAssertFalse(try isRestricted)
        XCTAssertFalse(tears.top)
        XCTAssertFalse(tears.bottom)

        try undo.redo()
        XCTAssertEqual(textView.string, section1)
    }

    // MARK: - Highlighting lines

    func testHighlightsLines() {
        controller.highlights = [[3, NSNumber(value: IFLineStyle.error.rawValue)],
                                 [9, NSNumber(value: IFLineStyle.highlight.rawValue)]]
        page.updateHighlightedLines()
        XCTAssertEqual(controller.highlightsAskedFor.last, "story.ni")

        // With the line's ending
        XCTAssertEqual(background(at: location(of: "Chapter 1")), NSColor(deviceRed: 0.7, green: 0.5, blue: 0.5, alpha: 1))
        XCTAssertNotNil(background(at: location(of: "Chapter 1") + 16))
        XCTAssertEqual(background(at: location(of: "The Cupboard")),
                       NSColor(deviceRed: 0.3, green: 0.8, blue: 0.8, alpha: 1))
        XCTAssertNil(background(at: location(of: "The Hall")))

        // Those that go are taken away
        controller.highlights = []
        page.updateHighlightedLines()
        XCTAssertNil(background(at: location(of: "Chapter 1")))
    }

    func testTheColoursOfHighlights() {
        let styles: [(IFLineStyle, NSColor)] = [
            (.neutral, NSColor(deviceRed: 0.3, green: 0.3, blue: 0.8, alpha: 1)),
            (.highlight, NSColor(deviceRed: 0.3, green: 0.8, blue: 0.8, alpha: 1)),
            (.error, NSColor(deviceRed: 0.7, green: 0.5, blue: 0.5, alpha: 1)),
            (.warning, NSColor(deviceRed: 0.8, green: 0.3, blue: 0.3, alpha: 1)),
            (.fatalError, NSColor(deviceRed: 0.8, green: 0.3, blue: 0.3, alpha: 1)),
        ]
        for (style, colour) in styles {
            controller.highlights = [[5, NSNumber(value: style.rawValue)]]
            page.updateHighlightedLines()
            XCTAssertEqual(background(at: location(of: "The Hall")), colour, "style \(style.rawValue)")
        }
    }

    func testHighlightsOnlyTheLinesInTheSectionShown() {
        controller.highlights = [[5, NSNumber(value: IFLineStyle.error.rawValue)],
                                 [13, NSNumber(value: IFLineStyle.error.rawValue)]]
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        XCTAssertNotNil(background(at: shownRange(of: "The Hall").location))
        XCTAssertNil(background(at: shownRange(of: "Chapter 1").location))
        XCTAssertNil(background(at: shownRange(of: "The Cupboard").location))
    }

    // MARK: - The headings page

    func testTogglesTheHeadingsPage() throws {
        page.toggleHeaderPage(nil)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.off, .on])
        XCTAssertFalse(textView.isDescendant(of: page.view))

        // Already shown
        page.showHeaderPage(nil)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.off, .on])

        page.toggleHeaderPage(nil)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.on, .off])
        XCTAssertTrue(textView.isDescendant(of: page.view))
    }

    func testTheCellsShowTheirPages() throws {
        let cells = page.toolbarCells
        let source = cells[0]
        let headings = cells[1]
        NSApp.sendAction(try XCTUnwrap(headings.action), to: headings.target, from: headings)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.off, .on])

        NSApp.sendAction(try XCTUnwrap(source.action), to: source.target, from: source)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.on, .off])
        XCTAssertTrue(textView.isDescendant(of: page.view))
    }

    func testShowingASectionShowsTheSource() throws {
        page.toggleHeaderPage(nil)
        waitForAnimations()
        putCursor(before: "Hall is")
        page.showCurrentSectionOnly(nil)
        waitForAnimations()
        XCTAssertEqual(cellStates, [.on, .off])
        XCTAssertEqual(textView.string, chapter1)
    }

    // MARK: - Renaming a heading in the headings page

    /// A node for a heading, as the headings page has
    private func node(_ name: String, called headingName: String? = nil) throws -> IFHeaderNode {
        let symbol = try heading(name)
        let header = IFHeader(name: headingName ?? symbol.name ?? "", parent: nil, children: nil)
        header.symbol = symbol
        return IFHeaderNode(header: header, position: .zero, depth: 0)
    }

    func testRenamesAHeading() throws {
        let chapter = try node("Chapter 1")

        try undo.beginUndoGrouping()
        page.headerView(IFHeaderView(frame: .zero), update: chapter, withNewTitle: "Chapter 1 - The Hall\n")
        try undo.endUndoGrouping()

        let renamed = story.replacingOccurrences(of: "Chapter 1 - Hall", with: "Chapter 1 - The Hall")
        XCTAssertEqual(try storage.string, renamed)
        // Showing the heading's section
        XCTAssertEqual(textView.string, chapter1.replacingOccurrences(of: "Chapter 1 - Hall", with: "Chapter 1 - The Hall"))
        // With the headings updated
        XCTAssertEqual(controller.headerController.rootHeader?.children.first?.children.first?.headingName,
                       "Chapter 1 - The Hall\n")

        try undo.undo()
        XCTAssertEqual(try storage.string, story)
        XCTAssertEqual(textView.string, story)
        XCTAssertFalse(try isRestricted)
    }

    func testDoesntRenameAHeadingThatsChangedOrToTheSameName() throws {
        page.headerView(IFHeaderView(frame: .zero), update: try node("Chapter 1", called: "Chapter 1 - Lobby\n"),
                        withNewTitle: "Chapter 1 - The Hall\n")
        page.headerView(IFHeaderView(frame: .zero), update: try node("Chapter 1"), withNewTitle: "Chapter 1 - Hall\n")
        XCTAssertEqual(try storage.string, story)
        XCTAssertEqual(textView.string, story)
        XCTAssertFalse(try isRestricted)
    }
}
