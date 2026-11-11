//
//  IFNaturalIntelTests.swift
//  InformTests
//

import XCTest

/// Gathering the headings of Inform 7 source, and the indenting and numbering done as it's typed.
@MainActor
final class IFNaturalIntelTests: XCTestCase {

    private let source = """
        "Numbering" by Tester

        Chapter 1 - Doors

        Section 1 - Front

        Section 2 - Back

        Chapter 2 - Windows

        The Window is a door.

        """

    /// A text storage registered with Inform 7 intelligence for the test, and unregistered at the end.
    private func registered(_ text: String) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFNaturalIntelTests", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: nil)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }
        return storage
    }

    /// The level and name of each heading gathered from the storage, in order.
    private func headings(in storage: NSTextStorage) throws -> [String] {
        let intel = try XCTUnwrap(IFSyntaxManager.intelligenceData(for: storage))
        var headings: [String] = []
        var symbol = intel.firstSymbol
        while let heading = symbol {
            headings.append("\(heading.level): \(heading.name ?? "(nil)")")
            symbol = heading.next
        }
        return headings
    }

    /// The location of the first match of some text.
    private func location(of find: String, in storage: NSTextStorage,
                          file: StaticString = #filePath, line: UInt = #line) -> Int {
        let range = (storage.string as NSString).range(of: find)
        XCTAssertNotEqual(range.location, NSNotFound, find, file: file, line: line)
        return range.location
    }

    /// Types text one character at a time at a location.
    private func type(_ text: String, at location: Int, in storage: NSTextStorage) {
        var location = location
        for character in text {
            let length = storage.length
            storage.replaceCharacters(in: NSRange(location: location, length: 0), with: String(character))
            location += storage.length - length
        }
    }

    /// Starts a paragraph before some text with a heading word, then types the space after it, which
    /// numbers the heading, and lets the run loop renumber the headings after it.
    private func typeHeading(_ word: String, before find: String, in storage: NSTextStorage,
                             file: StaticString = #filePath, line: UInt = #line) {
        let start = location(of: find, in: storage, file: file, line: line)
        storage.replaceCharacters(in: NSRange(location: start, length: 0), with: word + "\n\n")
        type(" ", at: start + (word as NSString).length, in: storage)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    private func skipUnlessNumbering() throws {
        try XCTSkipUnless(IFPreferences.shared.autoNumberSections, "Numbering sections is turned off in Inform's preferences")
    }

    // MARK: - Gathering headings

    func testHeadingsAreGatheredAtTheirLevels() throws {
        let storage = registered("""
            "Levels" by Tester

            Volume 1 - Everything

            Book 1 - Most

            Part 1 - Much

            Chapter 1 - Some

            Section 1 - Little

            Example: * Showing Off

            ---- Documentation ----

            """)
        XCTAssertEqual(try headings(in: storage), [
            "0: \"Levels\"",
            "1: Volume 1 - Everything\n",
            "2: Book 1 - Most\n",
            "3: Part 1 - Much\n",
            "4: Chapter 1 - Some\n",
            "5: Section 1 - Little\n",
            "6: Example: * Showing Off\n",
            "0: ---- Documentation ----\n",
        ])
    }

    func testHeadingsCanBeIndentedOrInCapitals() throws {
        let storage = registered("\"Shouting\" by Tester\n\n\tCHAPTER 1 - LOUD\n\nSection: Quiet\n")
        XCTAssertEqual(try headings(in: storage), ["0: \"Shouting\"", "4: \tCHAPTER 1 - LOUD\n", "5: Section: Quiet\n"])
    }

    func testAStoryWithoutATitleIsCalledStory() throws {
        let storage = registered("The Kitchen is a room.\n\nChapter 1 - Cooking\n")
        XCTAssertEqual(try headings(in: storage), ["0: \(IFUtility.localizedString("Story"))", "4: Chapter 1 - Cooking\n"])
    }

    func testAStoryThatStartsWithAHeadingHasNoTitle() throws {
        let storage = registered("Chapter 1 - Cooking\n\nThe Kitchen is a room.\n")
        XCTAssertEqual(try headings(in: storage), ["4: Chapter 1 - Cooking\n"])
    }

    func testEditingAHeadingUpdatesIt() throws {
        let storage = registered(source)
        storage.replaceCharacters(in: (storage.string as NSString).range(of: "Front"), with: "Porch")
        XCTAssertEqual(try headings(in: storage)[2], "5: Section 1 - Porch\n")

        storage.replaceCharacters(in: (storage.string as NSString).range(of: "Section 1 - Porch"), with: "The porch is gone.")
        XCTAssertEqual(try headings(in: storage), [
            "0: \"Numbering\"",
            "4: Chapter 1 - Doors\n",
            "5: Section 2 - Back\n",
            "4: Chapter 2 - Windows\n",
        ])
    }

    // MARK: - Indenting new lines

    /// A colon in a string doesn't start a rule, so it doesn't indent the next line any further.
    func testANewLineInAStringIsIndentedAsTheLineBefore() throws {
        try XCTSkipUnless(IFPreferences.shared.indentAfterNewline, "Indenting new lines is turned off in Inform's preferences")
        let text = "\"Strings\" by Tester\n\nWhen play begins:\n\tsay \"Note:\n"
        let storage = registered(text)
        type("\n", at: location(of: "Note:", in: storage) + 5, in: storage)
        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "Note:", with: "Note:\n\t"))
    }

    func testANewLineAfterAnUnindentedLineIsLeftAlone() throws {
        let storage = registered(source)
        type("\n", at: location(of: "The Window", in: storage), in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "The Window", with: "\nThe Window"))
    }

    // MARK: - Numbering headings

    func testTheFirstSectionOfAChapterIsNumberedOne() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Section", before: "The Window", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "The Window", with: "Section 1 - \n\nThe Window"))
    }

    func testTheFirstHeadingAtALevelIsNumberedOne() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Volume", before: "Chapter 1", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 1", with: "Volume 1 - \n\nChapter 1"))
    }

    func testASectionIsNumberedAfterTheOneBeforeIt() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Section", before: "Chapter 2", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 2", with: "Section 3 - \n\nChapter 2"))
    }

    /// The chapter is numbered after the one the section before it is in, and the chapter after it is renumbered.
    func testAChapterIsNumberedAfterTheChapterBeforeIt() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Chapter", before: "Chapter 2", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 2", with: "Chapter 2 - \n\nChapter 3"))
    }

    func testHeadingWordsInCapitalsAreNumbered() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("SECTION", before: "Chapter 2", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 2", with: "SECTION 3 - \n\nChapter 2"))
    }

    /// The heading before is there but its number isn't known, so the new one is left to the author.
    func testAHeadingAfterAnUnnumberedOneIsLeftAlone() throws {
        try skipUnlessNumbering()
        let text = source.replacingOccurrences(of: "Section 2 - Back", with: "Section Back")
        let storage = registered(text)
        typeHeading("Section", before: "Chapter 2", in: storage)
        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "Chapter 2", with: "Section \n\nChapter 2"))
    }

    func testOnlyAHeadingWordOnItsOwnIsNumbered() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Sections", before: "The Window", in: storage)
        typeHeading("Section 4", before: "The Window", in: storage)
        typeHeading("Examples are", before: "The Window", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(
            of: "The Window", with: "Sections \n\nSection 4 \n\nExamples are \n\nThe Window"))
    }

    func testExamplesAreNotNumbered() throws {
        try skipUnlessNumbering()
        let storage = registered(source)
        typeHeading("Example", before: "The Window", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "The Window", with: "Example \n\nThe Window"))
    }

    func testAHeadingInAStringIsNotNumbered() throws {
        try skipUnlessNumbering()
        let text = "\"Strings\" by Tester\n\nWhen play begins:\n\tsay \"The first line,\nthe second line.\"\n"
        let storage = registered(text)
        let start = location(of: "the second", in: storage)
        storage.replaceCharacters(in: NSRange(location: start, length: 0), with: "Chapter\n")
        type(" ", at: start + 7, in: storage)
        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "the second", with: "Chapter \nthe second"))
    }

    // MARK: - Renumbering the headings after a new one

    func testOnlyTheSectionsOfTheSameChapterAreRenumbered() throws {
        try skipUnlessNumbering()
        let text = source.replacingOccurrences(of: "The Window is", with: "Section 1 - Glass\n\nThe Window is")
        let storage = registered(text)
        typeHeading("Section", before: "Section 2", in: storage)
        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "Section 2 - Back", with: "Section 2 - \n\nSection 3 - Back"))
    }

    /// Rewriting a section that's already right would add an undo step that changes nothing.
    func testSectionsAlreadyNumberedRightAreLeftAlone() throws {
        try skipUnlessNumbering()
        // The section after the new one needs renumbering, but the one after that is right
        let text = source.replacingOccurrences(of: "Section 2 - Back", with: "Section 2 - Side\n\nSection 4 - Back")
        nonisolated(unsafe) let storage = registered(text)
        let start = location(of: "Section 2", in: storage)
        storage.replaceCharacters(in: NSRange(location: start, length: 0), with: "Section\n\n")
        type(" ", at: start + 7, in: storage)

        nonisolated(unsafe) var renumbered: [String] = []
        let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification,
                                                              object: storage, queue: nil) { _ in
            if storage.editedMask.contains(.editedCharacters) {
                renumbered.append((storage.string as NSString).substring(with: storage.editedRange))
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "Section 2 - Side", with: "Section 2 - \n\nSection 3 - Side"))
        XCTAssertEqual(renumbered, ["Section 3 - Side\n"])
    }

    /// Sections before the first chapter come under the title, as the chapters do, but aren't numbered with them.
    func testRenumberingStopsAtAHigherHeading() throws {
        try skipUnlessNumbering()
        let text = """
            "Loose" by Tester

            Section 1 - Setting Up

            Chapter 1 - Starting

            Chapter 2 - Going On

            """
        let storage = registered(text)
        typeHeading("Section", before: "Chapter 1", in: storage)
        XCTAssertEqual(storage.string, text.replacingOccurrences(of: "Chapter 1", with: "Section 2 - \n\nChapter 1"))
    }
}
