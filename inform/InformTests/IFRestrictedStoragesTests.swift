//
//  IFRestrictedStoragesTests.swift
//  InformTests
//

import XCTest

/// A delegate of the restricted storages that does nothing, as IFSyntaxData does while it keeps them in step
private final class StorageDelegate: NSObject, NSTextStorageDelegate {
}

/// The text storages of the views that show part of a text, kept in step with edits to the text
@MainActor
final class IFRestrictedStoragesTests: XCTestCase {

    /// The attribute that stands for the highlighting
    private let style = NSAttributedString.Key("IFRestrictedStoragesTestsStyle")
    private let delegate = StorageDelegate()

    /// "Chapter 1\n" is the range (0, 10), and "Chapter 2\n" (10, 10)
    private let chapters = "Chapter 1\nChapter 2\n"

    private func textView() -> NSTextView {
        return NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
    }

    /// A text with each character highlighted with its index
    private func text(_ string: String) -> NSTextStorage {
        let text = NSTextStorage(string: string)
        for index in 0..<text.length {
            text.addAttribute(style, value: index, range: NSRange(location: index, length: 1))
        }
        return text
    }

    /// Edits the text or a restricted storage as typing or pasting does, and keeps the storages in step as
    /// IFSyntaxData does: an edit made in a restricted storage is mirrored into the text, the range of the text given
    /// (or else the edit's new characters) is highlighted with the value given, and the restricted storages are
    /// updated
    private func edit(_ storage: NSTextStorage, of storages: IFRestrictedStorages, text: NSTextStorage,
                      at location: Int, replacing length: Int, with string: String,
                      highlighting: NSRange? = nil, as value: Int = -1) {
        let changeInLength = (string as NSString).length - length
        var newRange = NSRange(location: location, length: (string as NSString).length)
        storage.replaceCharacters(in: NSRange(location: location, length: length), with: string)

        text.beginEditing()
        if storage !== text {
            storages.mirrorChange(in: storage,
                                  replaceRange: NSRange(location: location, length: length),
                                  withAttributedString: storage.attributedSubstring(from: newRange))
            newRange.location += storages.locationInText(of: storage)
        }
        let highlighted = highlighting ?? newRange
        text.addAttribute(style, value: value, range: highlighted)
        storages.update(afterEditingRange: newRange,
                        changeInLength: changeInLength,
                        changedAttributesRange: highlighted,
                        editedStorage: storage)
        text.endEditing()
    }

    /// Checks that the view's storage holds the given text, which is its restricted range of the text, with the same
    /// attributes
    private func assertView(_ view: NSTextView, in storages: IFRestrictedStorages, of text: NSTextStorage,
                            shows expected: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let storage = storages.restrictedTextStorage(for: view) else {
            return XCTFail("The view isn't restricted", file: file, line: line)
        }
        XCTAssertEqual(storage.string, expected, file: file, line: line)
        let range = storages.restrictedRange(for: view)
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else {
            return XCTFail("The restricted range \(range) is outside the text", file: file, line: line)
        }
        let inText = text.attributedSubstring(from: range)
        XCTAssertEqual(inText.string, expected, "The restricted range", file: file, line: line)
        XCTAssertTrue(storage.isEqual(to: inText), "The attributes", file: file, line: line)
    }

    // MARK: - Restricting views

    /// A view has no restricted storage until it's given one
    func testAViewIsntRestrictedAtFirst() {
        let storages = IFRestrictedStorages(textStorage: text(chapters))
        let view = textView()
        XCTAssertFalse(storages.isRestricted(for: view))
        XCTAssertEqual(storages.restrictedRange(for: view).location, NSNotFound)
        XCTAssertNil(storages.restrictedTextStorage(for: view))
    }

    /// A restricted view shows a storage of its own, holding its range of the text with the text's attributes
    func testRestrictingAView() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)

        XCTAssertTrue(storages.isRestricted(for: view))
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 10, length: 10))
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))
        XCTAssertTrue(view.textStorage === storage)
        XCTAssertTrue(storage.delegate === delegate)
        XCTAssertEqual(text.string, chapters)
    }

    /// Restricting a view again shows the new range in the same storage, as the text view undoes what was typed in the
    /// storage it was typed in
    func testRestrictingAViewAgain() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 0, length: 10), for: view, delegate: delegate)
        let old = try XCTUnwrap(storages.restrictedTextStorage(for: view))

        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let new = try XCTUnwrap(storages.restrictedTextStorage(for: view))
        XCTAssertTrue(new === old)
        XCTAssertTrue(view.textStorage === new)
        XCTAssertTrue(new.delegate === delegate)
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")

        // Only the new range is kept in step
        edit(text, of: storages, text: text, at: 8, replacing: 1, with: "One")
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")
        edit(text, of: storages, text: text, at: 20, replacing: 1, with: "Two")
        assertView(view, in: storages, of: text, shows: "Chapter Two\n")
    }

    /// Removing a view's restriction lets go of its storage, though the view still shows it, and it keeps its text
    func testRemovingARestriction() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))

        storages.removeRestriction(for: view)
        XCTAssertFalse(storages.isRestricted(for: view))
        XCTAssertEqual(storages.restrictedRange(for: view).location, NSNotFound)
        XCTAssertNil(storages.restrictedTextStorage(for: view))
        XCTAssertEqual(storage.string, "Chapter 2\n")
        XCTAssertNil(storage.delegate)
        XCTAssertTrue(view.textStorage === storage)
        XCTAssertEqual(text.string, chapters)

        // It's no longer kept in step
        edit(text, of: storages, text: text, at: 18, replacing: 1, with: "Two")
        XCTAssertEqual(storage.string, "Chapter 2\n")

        // The view's next restriction shows its range in the same storage
        storages.restrict(to: NSRange(location: 0, length: 10), for: view, delegate: delegate)
        XCTAssertTrue(storages.restrictedTextStorage(for: view) === storage)
        assertView(view, in: storages, of: text, shows: "Chapter 1\n")
    }

    /// Removing a restriction from a view that has none does nothing
    func testRemovingARestrictionThatIsntThere() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)

        storages.removeRestriction(for: textView())
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")
    }

    /// Each view has its own storage, which can be removed without the other's
    func testTwoViews() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let first = textView()
        let second = textView()
        storages.restrict(to: NSRange(location: 0, length: 10), for: first, delegate: delegate)
        storages.restrict(to: NSRange(location: 10, length: 10), for: second, delegate: delegate)
        assertView(first, in: storages, of: text, shows: "Chapter 1\n")
        assertView(second, in: storages, of: text, shows: "Chapter 2\n")

        storages.removeRestriction(for: first)
        XCTAssertFalse(storages.isRestricted(for: first))
        assertView(second, in: storages, of: text, shows: "Chapter 2\n")
    }

    /// A restricted storage's characters start at its range's location in the text; any other storage's, at 0
    func testWhereAStoragesCharactersStartInTheText() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))
        XCTAssertEqual(storages.locationInText(of: storage), 10)
        XCTAssertEqual(storages.locationInText(of: text), 0)
        XCTAssertEqual(storages.locationInText(of: NSTextStorage(string: "Other")), 0)

        edit(text, of: storages, text: text, at: 0, replacing: 0, with: "Part 1\n")
        XCTAssertEqual(storages.locationInText(of: storage), 17)
    }

    // MARK: - Edits

    /// A change made in a restricted storage is made in the text at the same place, with the same attributes
    func testMirroringAChangeIntoTheText() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))

        storage.replaceCharacters(in: NSRange(location: 8, length: 1), with: "Two")
        storage.addAttribute(style, value: 99, range: NSRange(location: 8, length: 3))
        storages.mirrorChange(in: storage,
                              replaceRange: NSRange(location: 8, length: 1),
                              withAttributedString: storage.attributedSubstring(from: NSRange(location: 8, length: 3)))
        XCTAssertEqual(text.string, "Chapter 1\nChapter Two\n")
        XCTAssertEqual(text.attribute(style, at: 18, effectiveRange: nil) as? Int, 99)
        XCTAssertEqual(text.attribute(style, at: 20, effectiveRange: nil) as? Int, 99)
        XCTAssertEqual(text.attribute(style, at: 21, effectiveRange: nil) as? Int, 19)
    }

    /// An edit before a restricted range moves it
    func testAnEditBeforeARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 0, replacing: 0, with: "Part 1\n")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 17, length: 10))
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")
    }

    /// An edit after a restricted range leaves it as it was
    func testAnEditAfterARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 0, length: 9), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 10, replacing: 7, with: "Part")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 0, length: 9))
        assertView(view, in: storages, of: text, shows: "Chapter 1")
    }

    /// An edit within a restricted range is copied into its storage
    func testAnEditWithinARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 18, replacing: 1, with: "Two")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 10, length: 12))
        assertView(view, in: storages, of: text, shows: "Chapter Two\n")
    }

    /// What's inserted at the start or the end of a restricted range becomes part of it
    func testInsertingAtTheStartOrEndOfARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 9), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 10, replacing: 0, with: "The ")
        assertView(view, in: storages, of: text, shows: "The Chapter 2")
        edit(text, of: storages, text: text, at: 23, replacing: 0, with: " ends")
        assertView(view, in: storages, of: text, shows: "The Chapter 2 ends")
        XCTAssertEqual(text.string, "Chapter 1\nThe Chapter 2 ends\n")
    }

    /// An edit replacing text across the start of a restricted range takes the characters it replaced out of the
    /// range, and puts the new ones before it
    func testAnEditAcrossTheStartOfARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 8, replacing: 6, with: "X")
        XCTAssertEqual(text.string, "Chapter Xter 2\n")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 9, length: 6))
        assertView(view, in: storages, of: text, shows: "ter 2\n")
    }

    /// An edit replacing text across the end of a restricted range takes the characters it replaced out of the
    /// range, and puts the new ones at its end
    func testAnEditAcrossTheEndOfARestrictedRange() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 0, length: 10), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 8, replacing: 4, with: "X")
        XCTAssertEqual(text.string, "Chapter Xapter 2\n")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 0, length: 9))
        assertView(view, in: storages, of: text, shows: "Chapter X")
    }

    /// An edit replacing all of a restricted range and the text around it leaves the range empty, after the new text
    func testAnEditReplacingARestrictedRangeAndTheTextAroundIt() {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 9), for: view, delegate: delegate)

        edit(text, of: storages, text: text, at: 8, replacing: 12, with: "X")
        XCTAssertEqual(text.string, "Chapter X")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 9, length: 0))
        assertView(view, in: storages, of: text, shows: "")
    }

    /// An edit made in a restricted storage is mirrored into the text, and the range takes in the new characters
    func testAnEditInARestrictedStorage() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))

        edit(storage, of: storages, text: text, at: 8, replacing: 1, with: "Two")
        XCTAssertEqual(text.string, "Chapter 1\nChapter Two\n")
        XCTAssertEqual(storages.restrictedRange(for: view), NSRange(location: 10, length: 12))
        assertView(view, in: storages, of: text, shows: "Chapter Two\n")
    }

    /// An edit made in one restricted storage is copied into another that shows the same text
    func testAnEditInOneRestrictedStorageIsCopiedIntoAnother() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let first = textView()
        let second = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: first, delegate: delegate)
        storages.restrict(to: NSRange(location: 10, length: 10), for: second, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: first))

        edit(storage, of: storages, text: text, at: 8, replacing: 1, with: "Two")
        assertView(first, in: storages, of: text, shows: "Chapter Two\n")
        assertView(second, in: storages, of: text, shows: "Chapter Two\n")
    }

    /// The text's highlighting, after an edit, is copied into the restricted storages where their ranges meet it
    func testTheHighlightingIsCopied() throws {
        let text = text(chapters)
        let storages = IFRestrictedStorages(textStorage: text)
        let view = textView()
        storages.restrict(to: NSRange(location: 10, length: 10), for: view, delegate: delegate)
        let storage = try XCTUnwrap(storages.restrictedTextStorage(for: view))

        edit(text, of: storages, text: text, at: 8, replacing: 1, with: "One",
             highlighting: NSRange(location: 8, length: 12), as: 99)
        assertView(view, in: storages, of: text, shows: "Chapter 2\n")
        XCTAssertEqual(storage.attribute(style, at: 0, effectiveRange: nil) as? Int, 99)
        XCTAssertEqual(storage.attribute(style, at: 7, effectiveRange: nil) as? Int, 99)
        XCTAssertEqual(storage.attribute(style, at: 8, effectiveRange: nil) as? Int, 18)
    }

    /// Where a range is after an edit, worked out afresh: the characters the edit replaced come out of it, and those
    /// it puts in go before it if the edit starts before the range, or into it if the edit starts within it or at
    /// its end
    private func adjusted(_ range: NSRange, at location: Int, replacing length: Int, with newLength: Int) -> NSRange {
        let removedBefore = max(0, min(range.location, location + length) - location)
        let removedWithin = max(0, min(NSMaxRange(range), location + length) - max(range.location, location))
        var result = NSRange(location: range.location - removedBefore, length: range.length - removedWithin)
        if location < range.location {
            result.location += newLength
        } else if location <= NSMaxRange(range) {
            result.length += newLength
        }
        return result
    }

    /// Through many random edits, made in the text and in the views' storages, while the views are restricted to
    /// other ranges now and then, each view's storage holds its range of the text, with the text's attributes
    func testManyEdits() {
        // A fixed sequence of numbers, so that a failure can be repeated
        var seed: UInt64 = 12345
        func random(_ upperBound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(upperBound))
        }
        let letters = Array("ab \n")

        let text = text(String(repeating: "Some text.\n", count: 20))
        let storages = IFRestrictedStorages(textStorage: text)
        let views = [textView(), textView()]
        var ranges: [NSRange?] = [NSRange(location: 11, length: 22), NSRange(location: 22, length: 33)]
        for (view, range) in zip(views, ranges) {
            storages.restrict(to: range!, for: view, delegate: delegate)
        }

        var restrictedEdits = 0
        for step in 0..<2000 {
            // Now and then, restrict a view to another range, or remove its restriction
            if random(50) == 0 {
                let index = random(views.count)
                if random(4) == 0 {
                    storages.removeRestriction(for: views[index])
                    ranges[index] = nil
                } else {
                    let location = random(text.length + 1)
                    let range = NSRange(location: location, length: random(text.length - location + 1))
                    storages.restrict(to: range, for: views[index], delegate: delegate)
                    ranges[index] = range
                }
            }

            // Edit the text, or one of the views' storages
            let index = random(views.count + 1)
            var storage = text
            var offset = 0
            if index < views.count, let range = ranges[index],
               let restricted = storages.restrictedTextStorage(for: views[index]) {
                storage = restricted
                offset = range.location
                restrictedEdits += 1
            }
            let location = random(storage.length + 1)
            let length = random(min(storage.length - location, 8) + 1)
            let string = String((0..<random(10)).map { _ in letters[random(letters.count)] })
            let newLength = (string as NSString).length

            // Highlight the new characters and some of those around them
            let start = max(0, offset + location - random(10))
            let end = min(offset + location + newLength + random(10), text.length - length + newLength)
            edit(storage, of: storages, text: text, at: location, replacing: length, with: string,
                 highlighting: NSRange(location: start, length: end - start), as: step)
            ranges = ranges.map { $0.map { adjusted($0, at: offset + location, replacing: length, with: newLength) } }

            var failed = false
            for (view, range) in zip(views, ranges) {
                guard let range else {
                    XCTAssertFalse(storages.isRestricted(for: view), "after edit \(step)")
                    continue
                }
                XCTAssertEqual(storages.restrictedRange(for: view), range, "after edit \(step)")
                guard let shown = storages.restrictedTextStorage(for: view), NSMaxRange(range) <= text.length else {
                    XCTFail("The view or its range is lost after edit \(step)")
                    failed = true
                    continue
                }
                let inText = text.attributedSubstring(from: range)
                XCTAssertEqual(shown.string, inText.string, "after edit \(step)")
                XCTAssertTrue(shown.isEqual(to: inText), "The attributes after edit \(step)")
                if storages.restrictedRange(for: view) != range || !shown.isEqual(to: inText) {
                    failed = true
                }
            }
            if failed { break }
        }
        XCTAssertGreaterThan(text.length, 100)
        XCTAssertGreaterThan(restrictedEdits, 500)
    }
}
