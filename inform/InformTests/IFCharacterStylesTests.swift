//
//  IFCharacterStylesTests.swift
//  InformTests
//

import XCTest

final class IFCharacterStylesTests: XCTestCase {

    private let notHighlighted = IFSyntaxStyle.styleNotHighlighted

    /// The style of each character
    private func styles(_ characterStyles: IFCharacterStyles) -> [IFSyntaxStyle] {
        return (0..<characterStyles.count).map { characterStyles.style(at: $0) }
    }

    /// The styles of a text of characters with the given styles, made by inserting the characters and then
    /// highlighting them
    private func characterStyles(_ list: [IFSyntaxStyle]) -> IFCharacterStyles {
        let result = IFCharacterStyles()
        result.replaceStyles(afterEditingRange: NSRange(location: 0, length: list.count), changeInLength: list.count)
        for (index, style) in list.enumerated() {
            result.setStyle(style, at: index)
        }
        return result
    }

    /// An edit replacing `length` characters at `location` with `newLength` others
    private func edit(_ characterStyles: IFCharacterStyles,
                      at location: Int, replacing length: Int, with newLength: Int) {
        characterStyles.replaceStyles(afterEditingRange: NSRange(location: location, length: newLength),
                                      changeInLength: newLength - length)
    }

    // MARK: - Reading and writing

    /// An empty text has no styles
    func testAnEmptyTextHasNoStyles() {
        let characterStyles = IFCharacterStyles()
        XCTAssertEqual(characterStyles.count, 0)
        XCTAssertEqual(characterStyles.style(at: 0), [])
    }

    /// Each character has the style it's given
    func testEachCharacterHasTheStyleItsGiven() {
        let characterStyles = self.characterStyles([.string, .comment, .heading])
        XCTAssertEqual(characterStyles.count, 3)
        XCTAssertEqual(styles(characterStyles), [.string, .comment, .heading])

        characterStyles.setStyle(.gameText, at: 1)
        XCTAssertEqual(styles(characterStyles), [.string, .gameText, .heading])
    }

    /// The index just after the last character has no style
    func testTheIndexAfterTheLastCharacterHasNoStyle() {
        XCTAssertEqual(characterStyles([.string, .comment]).style(at: 2), [])
    }

    // MARK: - Edits

    /// The characters an edit inserts aren't highlighted
    func testInsertedCharactersAreNotHighlighted() {
        let characterStyles = IFCharacterStyles()
        edit(characterStyles, at: 0, replacing: 0, with: 3)
        XCTAssertEqual(styles(characterStyles), [notHighlighted, notHighlighted, notHighlighted])
    }

    /// The characters after an insertion keep their styles
    func testInsertingMovesTheStylesAfterIt() {
        let characterStyles = self.characterStyles([.string, .comment, .heading, .gameText])
        edit(characterStyles, at: 2, replacing: 0, with: 2)
        XCTAssertEqual(styles(characterStyles),
                       [.string, .comment, notHighlighted, notHighlighted, .heading, .gameText])
    }

    /// Characters can be inserted at the start and the end
    func testInsertingAtTheStartAndTheEnd() {
        let characterStyles = self.characterStyles([.string, .comment])
        edit(characterStyles, at: 0, replacing: 0, with: 1)
        edit(characterStyles, at: 3, replacing: 0, with: 1)
        XCTAssertEqual(styles(characterStyles), [notHighlighted, .string, .comment, notHighlighted])
    }

    /// The characters after a deletion keep their styles
    func testDeletingMovesTheStylesAfterIt() {
        let characterStyles = self.characterStyles([.string, .comment, .heading, .gameText, .string])
        edit(characterStyles, at: 1, replacing: 2, with: 0)
        XCTAssertEqual(styles(characterStyles), [.string, .gameText, .string])
    }

    /// Deleting every character leaves no styles
    func testDeletingEverything() {
        let characterStyles = self.characterStyles([.string, .comment])
        edit(characterStyles, at: 0, replacing: 2, with: 0)
        XCTAssertEqual(characterStyles.count, 0)
        XCTAssertEqual(characterStyles.style(at: 0), [])
    }

    /// Characters replaced by more, fewer or the same number aren't highlighted, and those after them keep their styles
    func testReplacingCharacters() {
        let more = characterStyles([.string, .comment, .heading, .gameText])
        edit(more, at: 1, replacing: 2, with: 3)
        XCTAssertEqual(styles(more), [.string, notHighlighted, notHighlighted, notHighlighted, .gameText])

        let fewer = characterStyles([.string, .comment, .heading, .gameText])
        edit(fewer, at: 1, replacing: 2, with: 1)
        XCTAssertEqual(styles(fewer), [.string, notHighlighted, .gameText])

        let same = characterStyles([.string, .comment, .heading, .gameText])
        edit(same, at: 1, replacing: 2, with: 2)
        XCTAssertEqual(styles(same), [.string, notHighlighted, notHighlighted, .gameText])
    }

    /// An edit's effect on the styles is the same as it would be on a list of them, through many random edits
    func testManyEdits() {
        // A fixed sequence of numbers, so that a failure can be repeated
        var seed: UInt64 = 12345
        func random(_ upperBound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(upperBound))
        }
        let someStyles: [IFSyntaxStyle] = [.string, .comment, .heading, .gameText, .naturalInform]

        let characterStyles = IFCharacterStyles()
        var expected: [IFSyntaxStyle] = []
        for step in 0..<2000 {
            let location = random(expected.count + 1)
            let length = random(min(expected.count - location, 8) + 1)
            let newLength = random(10)
            edit(characterStyles, at: location, replacing: length, with: newLength)
            expected.replaceSubrange(location..<(location + length),
                                     with: Array(repeating: notHighlighted, count: newLength))

            // Highlight some of the characters
            for _ in 0..<random(4) where !expected.isEmpty {
                let index = random(expected.count)
                let style = someStyles[random(someStyles.count)]
                characterStyles.setStyle(style, at: index)
                expected[index] = style
            }

            XCTAssertEqual(styles(characterStyles), expected, "after edit \(step)")
            if styles(characterStyles) != expected { break }
        }
        XCTAssertGreaterThan(expected.count, 100)
    }

    // MARK: - Runs of a style

    /// The run of a character's style is the characters around it, and including it, with the same style
    func testTheRunOfACharactersStyle() {
        let characterStyles = self.characterStyles([.string, .string, .comment, .comment, .comment, .string])
        XCTAssertEqual(characterStyles.rangeOfStyle(at: 0), NSRange(location: 0, length: 2))
        XCTAssertEqual(characterStyles.rangeOfStyle(at: 1), NSRange(location: 0, length: 2))
        XCTAssertEqual(characterStyles.rangeOfStyle(at: 3), NSRange(location: 2, length: 3))
        XCTAssertEqual(characterStyles.rangeOfStyle(at: 5), NSRange(location: 5, length: 1))
    }

    /// A text of one style is one run
    func testATextOfOneStyleIsOneRun() {
        let characterStyles = self.characterStyles([.heading, .heading, .heading])
        XCTAssertEqual(characterStyles.rangeOfStyle(at: 1), NSRange(location: 0, length: 3))
    }

    // MARK: - The styles from a character

    /// The styles from a character on share the characters' styles
    func testTheStylesFromACharacterShareTheStyles() {
        let characterStyles = self.characterStyles([.string, .comment, .heading, .gameText])
        let fromSecond = characterStyles.styles(from: 1)
        XCTAssertEqual(fromSecond.numCharStyles, 3)
        XCTAssertEqual((0..<3).map { fromSecond.read($0) }, [.comment, .heading, .gameText])

        fromSecond.write(1, value: .naturalInform)
        XCTAssertEqual(styles(characterStyles), [.string, .comment, .naturalInform, .gameText])
        characterStyles.setStyle(.string, at: 3)
        XCTAssertEqual(fromSecond.read(2), .string)
    }

    /// The styles from the end of the text are empty
    func testTheStylesFromTheEndAreEmpty() {
        let fromEnd = characterStyles([.string, .comment]).styles(from: 2)
        XCTAssertEqual(fromEnd.numCharStyles, 0)
        XCTAssertEqual(fromEnd.read(0), [])
    }
}
