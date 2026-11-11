//
//  IFHeaderControllerTests.swift
//  InformTests
//

import XCTest

/// A header view that records each time it's told to refresh, and the headers it then finds
private final class RecordingHeaderView: NSView, IFHeaderViewProtocol {
    private(set) var controllers: [IFHeaderController] = []
    private(set) var roots: [IFHeader?] = []

    func refreshHeaders(_ controller: IFHeaderController) {
        controllers.append(controller)
        roots.append(controller.rootHeader)
    }
}

/// A header view that doesn't want to be told to refresh
private final class QuietHeaderView: NSView, IFHeaderViewProtocol {
}

@MainActor
final class IFHeaderControllerTests: XCTestCase {

    private func heading(_ name: String, level: Int32) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// A file with the given headings, one to a line
    private func file(_ headings: [(String, Int32)]) -> IFIntelFile {
        let file = IFIntelFile()
        for (line, (name, level)) in headings.enumerated() {
            file.add(heading(name, level: level), atLine: Int32(line))
        }
        return file
    }

    private let story: [(String, Int32)] = [
        ("The Story", 0),
        ("Part One", 3),
        ("Chapter 1", 4),
        ("Chapter 2", 4),
        ("Part Two", 3),
        ("Section A", 5),
    ]

    private let extensionWithDocumentation: [(String, Int32)] = [
        ("Locks by Jane Doe", 0),
        ("Chapter 1", 4),
        ("---- DOCUMENTATION ----", 0),
        ("Chapter: Using locks", 4),
        ("Section: Keys", 5),
    ]

    /// A header and those below it, with each one's children in brackets, checking that they know their parent
    private func outline(_ header: IFHeader?) -> String {
        guard let header else {
            return "none"
        }
        for child in header.children {
            XCTAssertIdentical(child.parent, header, child.headingName)
        }
        if header.children.isEmpty {
            return header.headingName
        }
        return header.headingName + " (" + header.children.map { outline($0) }.joined(separator: ", ") + ")"
    }

    /// Each header, in order, with the name of its symbol
    private func symbols(_ header: IFHeader?) -> [String] {
        guard let header else {
            return []
        }
        return ["\(header.headingName): \(header.symbol?.name ?? "-")"] + header.children.flatMap { symbols($0) }
    }

    /// The symbols in a file, in order
    private func symbolsIn(_ file: IFIntelFile) -> [IFIntelSymbol] {
        var result: [IFIntelSymbol] = []
        var symbol = file.firstSymbol
        while let current = symbol {
            result.append(current)
            symbol = current.next
        }
        return result
    }

    private var contents: String { IFUtility.localizedString("HeaderPage") }

    // MARK: - The headers

    func testTheHeadersOfAStory() {
        let controller = IFHeaderController()
        let file = file(story)
        controller.update(fromIntelligence: file)

        XCTAssertIdentical(controller.intelFile, file)
        XCTAssertNotNil(controller.rootHeader)
        XCTAssertNil(controller.rootHeader?.parent)
        XCTAssertEqual(outline(controller.rootHeader),
                       "\(contents) (The Story (Part One (Chapter 1, Chapter 2), Part Two (Section A)))")

        // The story's own header has no symbol, so choosing it shows the whole story
        XCTAssertEqual(symbols(controller.rootHeader),
                       ["\(contents): -", "The Story: -", "Part One: Part One", "Chapter 1: Chapter 1",
                        "Chapter 2: Chapter 2", "Part Two: Part Two", "Section A: Section A"])

        // The symbols are the file's own
        let fileSymbols = symbolsIn(file)
        let partOne = controller.rootHeader?.children[0].children[0]
        XCTAssertIdentical(partOne?.symbol, fileSymbols[1])
        XCTAssertIdentical(partOne?.children[1].symbol, fileSymbols[3])
    }

    func testAStoryWithNoHeadings() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file([("The Story", 0)]))

        XCTAssertEqual(outline(controller.rootHeader), "\(contents) (The Story)")
        XCTAssertEqual(controller.rootHeader?.children[0].children, [])
    }

    /// A file whose first line is a heading has no title, so its headings go under a header for the story, with
    /// no symbol, as a title's has
    func testTheHeadersOfAFileStartingWithAHeading() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file([("Volume 1", 1), ("Chapter 1", 4), ("Volume 2", 1)]))

        let story = IFUtility.localizedString("Story")
        XCTAssertEqual(outline(controller.rootHeader), "\(contents) (\(story) (Volume 1 (Chapter 1), Volume 2))")
        XCTAssertEqual(symbols(controller.rootHeader),
                       ["\(contents): -", "\(story): -", "Volume 1: Volume 1", "Chapter 1: Chapter 1",
                        "Volume 2: Volume 2"])
    }

    /// An extension's documentation, which starts with a heading on the top level, gets its own header beside the
    /// extension's
    func testTheHeadersOfAnExtensionWithDocumentation() {
        let controller = IFHeaderController()
        let file = file(extensionWithDocumentation)
        controller.update(fromIntelligence: file)

        let extensionTitle = IFUtility.localizedString("HeaderExtensionTitle")
        let documentation = IFUtility.localizedString("HeaderDocumentationTitle")
        XCTAssertEqual(outline(controller.rootHeader),
                       "\(contents) (\(extensionTitle) (Chapter 1), \(documentation) (Chapter: Using locks (Section: Keys)))")

        // The documentation's header has its heading's symbol; the extension's has none
        XCTAssertEqual(symbols(controller.rootHeader),
                       ["\(contents): -", "\(extensionTitle): -", "Chapter 1: Chapter 1",
                        "\(documentation): ---- DOCUMENTATION ----", "Chapter: Using locks: Chapter: Using locks",
                        "Section: Keys: Section: Keys"])
        XCTAssertIdentical(controller.rootHeader?.children[1].symbol, symbolsIn(file)[2])
    }

    func testEachUpdateMakesNewHeaders() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let firstRoot = controller.rootHeader

        let extensionFile = file(extensionWithDocumentation)
        controller.update(fromIntelligence: extensionFile)
        XCTAssertNotIdentical(controller.rootHeader, firstRoot)
        XCTAssertIdentical(controller.intelFile, extensionFile)
        XCTAssertEqual(controller.rootHeader?.children.count, 2)
    }

    /// A file with no symbols at all leaves the headers as they were, though it's the controller's file now
    func testAFileWithNoSymbolsKeepsTheHeaders() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let root = controller.rootHeader
        let view = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(view)

        let emptyFile = IFIntelFile()
        controller.update(fromIntelligence: emptyFile)
        XCTAssertIdentical(controller.rootHeader, root)
        XCTAssertIdentical(controller.intelFile, emptyFile)
        XCTAssertEqual(view.roots.count, 1)
    }

    func testNoIntelligenceKeepsTheHeaders() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let root = controller.rootHeader
        let view = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(view)

        controller.update(fromIntelligence: nil)
        XCTAssertNotNil(root)
        XCTAssertIdentical(controller.rootHeader, root)
        XCTAssertNil(controller.intelFile)
        XCTAssertEqual(view.roots.count, 1)
    }

    func testANewControllerHasNoHeaders() {
        let controller = IFHeaderController()
        XCTAssertNil(controller.rootHeader)
        XCTAssertNil(controller.intelFile)

        // A view added now is told to refresh, and finds none
        let view = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(view)
        XCTAssertEqual(view.roots.count, 1)
        XCTAssertNil(view.roots[0])

        // Nor does a file with no symbols give any
        controller.update(fromIntelligence: IFIntelFile())
        XCTAssertNil(controller.rootHeader)
        XCTAssertEqual(view.roots.count, 1)
    }

    // MARK: - The views

    func testAViewIsToldToRefreshWhenAddedAndOnEachUpdate() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let firstRoot = controller.rootHeader

        let view = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(view)
        XCTAssertEqual(view.controllers.count, 1)
        XCTAssertIdentical(view.controllers.first, controller)
        XCTAssertIdentical(view.roots[0], firstRoot)

        // It finds the new headers when it's told
        controller.update(fromIntelligence: file(extensionWithDocumentation))
        XCTAssertEqual(view.roots.count, 2)
        XCTAssertIdentical(view.roots[1], controller.rootHeader)
        XCTAssertNotIdentical(view.roots[1], firstRoot)
    }

    func testEachViewIsTold() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let first = RecordingHeaderView(frame: .zero)
        let second = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(first)
        controller.addHeaderView(second)

        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(first.roots.count, 2)
        XCTAssertEqual(second.roots.count, 2)
    }

    func testAViewIsOnlyAddedOnce() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let view = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(view)
        controller.addHeaderView(view)
        XCTAssertEqual(view.roots.count, 1)

        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(view.roots.count, 2)

        // So removing it once removes it
        controller.removeHeaderView(view)
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(view.roots.count, 2)
    }

    func testARemovedViewIsntTold() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let kept = RecordingHeaderView(frame: .zero)
        let removed = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(kept)
        controller.addHeaderView(removed)

        controller.removeHeaderView(removed)
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(kept.roots.count, 2)
        XCTAssertEqual(removed.roots.count, 1)

        // Removing a view that isn't there does nothing
        controller.removeHeaderView(removed)
        controller.removeHeaderView(RecordingHeaderView(frame: .zero))
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(kept.roots.count, 3)
    }

    func testAViewNeedNotRefresh() {
        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        let quiet = QuietHeaderView(frame: .zero)
        let recording = RecordingHeaderView(frame: .zero)
        controller.addHeaderView(quiet)
        controller.addHeaderView(recording)

        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(recording.roots.count, 2)
    }
}
