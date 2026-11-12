//
//  IFHighlighterStateTests.swift
//  InformTests
//

import XCTest

/// The highlighter's state as it runs through the lines of a text, and the callbacks it reads and changes it with
final class IFHighlighterStateTests: XCTestCase {

    private let defaultState = IFSyntaxState(IFSyntaxStateDefault)
    private let notHighlighted = IFSyntaxState(IFSyntaxStateNotHighlighted)

    /// The text's characters' styles, none of them highlighted, which the highlighter's state is given
    private var characterStyles = IFCharacterStyles()

    /// The highlighter's state for a text, with the text's characters' styles
    private func highlighterState(_ string: String) -> IFHighlighterState {
        let text = NSTextStorage(string: string)
        characterStyles = IFCharacterStyles()
        characterStyles.replaceStyles(afterEditingRange: NSRange(location: 0, length: text.length),
                                      changeInLength: text.length)
        return IFHighlighterState(text: text, characterStyles: characterStyles)
    }

    /// The state and mode a line starts in
    private func start(of line: Int, in highlighterState: IFHighlighterState) -> [UInt32] {
        highlighterState.startLine(line, at: 0)
        return [highlighterState.state, highlighterState.mode]
    }

    // MARK: - Each line's state

    /// A new text's one line starts in the default state and mode
    func testANewTextHasOneLineInTheDefaultState() {
        let highlighterState = highlighterState("Some text")
        XCTAssertEqual(highlighterState.lineCount, 1)
        highlighterState.startLine(0, at: 0)
        XCTAssertEqual(highlighterState.state, defaultState)
        XCTAssertEqual(highlighterState.mode, 0)
        XCTAssertEqual(highlighterState.position, 0)
    }

    /// Lines put in by an edit start not highlighted, and the lines before and after them keep their states
    func testReplacingLines() {
        let highlighterState = highlighterState("")
        highlighterState.replaceLines(after: 0, through: 0, with: 3)
        XCTAssertEqual(highlighterState.lineCount, 4)
        for line in 1...3 {
            XCTAssertEqual(start(of: line, in: highlighterState), [notHighlighted, 0], "line \(line)")
        }

        // Give each line a state of its own
        for line in 0..<3 {
            highlighterState.startLine(line, at: 0)
            highlighterState.state = UInt32(10 + line)
            highlighterState.mode = UInt32(20 + line)
            _ = highlighterState.finishLine(line)
        }

        // Lines 2 and 3 become one new line
        highlighterState.replaceLines(after: 1, through: 3, with: 1)
        XCTAssertEqual(highlighterState.lineCount, 3)
        XCTAssertEqual(start(of: 0, in: highlighterState), [defaultState, 0])
        XCTAssertEqual(start(of: 1, in: highlighterState), [10, 20])
        XCTAssertEqual(start(of: 2, in: highlighterState), [notHighlighted, 0])

        // Lines 1 and 2 go
        highlighterState.replaceLines(after: 0, through: 2, with: 0)
        XCTAssertEqual(highlighterState.lineCount, 1)
        XCTAssertEqual(start(of: 0, in: highlighterState), [defaultState, 0])
    }

    /// Starting a line goes to its first character, in the state and mode it starts in
    func testStartingALine() {
        let highlighterState = highlighterState("First\nSecond\n")
        highlighterState.replaceLines(after: 0, through: 0, with: 1)
        highlighterState.startLine(1, at: 6)
        XCTAssertEqual(highlighterState.position, 6)
        XCTAssertEqual(highlighterState.state, notHighlighted)
        XCTAssertEqual(highlighterState.mode, 0)
    }

    /// The next line starts with the stack as the line ends, with its last state and mode on top
    func testTheNextLineStartsWithTheStackAsTheLineEnds() {
        let highlighterState = highlighterState("First\nSecond\n")
        highlighterState.replaceLines(after: 0, through: 0, with: 1)
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 5
        highlighterState.mode = 2
        highlighterState.pushState()
        highlighterState.state = 7
        highlighterState.mode = 3
        XCTAssertFalse(highlighterState.finishLine(0))

        highlighterState.startLine(1, at: 6)
        XCTAssertEqual(highlighterState.state, 7)
        XCTAssertEqual(highlighterState.mode, 3)
        XCTAssertEqual(highlighterState.popState(), 5)
        XCTAssertEqual(highlighterState.mode, 2)
    }

    /// Finishing a line says whether the next line started that way already
    func testFinishingALineSaysWhetherTheNextLineStartedSo() {
        let highlighterState = highlighterState("First\nSecond\n")
        highlighterState.replaceLines(after: 0, through: 0, with: 1)
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 5
        XCTAssertFalse(highlighterState.finishLine(0))

        // The same again
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 5
        XCTAssertTrue(highlighterState.finishLine(0))

        // The same state with something saved under it
        highlighterState.startLine(0, at: 0)
        highlighterState.pushState()
        highlighterState.state = 5
        XCTAssertFalse(highlighterState.finishLine(0))

        // A different mode
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 5
        highlighterState.mode = 1
        XCTAssertFalse(highlighterState.finishLine(0))
        XCTAssertEqual(start(of: 1, in: highlighterState), [5, 1])
    }

    /// The last line's state at its end isn't kept, as no line starts with it
    func testFinishingTheLastLine() {
        let highlighterState = highlighterState("First")
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 5
        XCTAssertFalse(highlighterState.finishLine(0))
        XCTAssertEqual(highlighterState.lineCount, 1)
        XCTAssertEqual(start(of: 0, in: highlighterState), [defaultState, 0])
    }

    // MARK: - Saving states

    /// Popping a state gives the last state saved, and goes back to the mode saved with it, but leaves the state as it
    /// was: the highlighter goes to the state popped by returning it
    func testPushingAndPoppingStates() {
        let highlighterState = highlighterState("Text")
        highlighterState.startLine(0, at: 0)
        highlighterState.state = 1
        highlighterState.mode = 11
        highlighterState.pushState()
        highlighterState.state = 2
        highlighterState.mode = 12
        highlighterState.pushState()
        highlighterState.state = 3
        highlighterState.mode = 13

        XCTAssertEqual(highlighterState.popState(), 2)
        XCTAssertEqual(highlighterState.mode, 12)
        XCTAssertEqual(highlighterState.state, 3)
        XCTAssertEqual(highlighterState.popState(), 1)
        XCTAssertEqual(highlighterState.mode, 11)
        XCTAssertEqual(highlighterState.state, 3)
    }

    /// Popping with nothing saved gives the default state and mode
    func testPoppingWithNothingSaved() {
        let highlighterState = highlighterState("Text")
        highlighterState.startLine(0, at: 0)
        highlighterState.mode = 4
        XCTAssertEqual(highlighterState.popState(), defaultState)
        XCTAssertEqual(highlighterState.mode, 0)
    }

    // MARK: - Backtracking

    /// The styles of the characters before the position, up to the number given, are changed
    func testBacktracking() {
        let highlighterState = highlighterState("abcdef")
        highlighterState.startLine(0, at: 0)
        highlighterState.position = 4
        highlighterState.backtrack(with: .comment, length: 3)
        XCTAssertEqual((0..<6).map { characterStyles.style(at: $0) },
                       [.styleNotHighlighted, .comment, .comment, .comment, .styleNotHighlighted, .styleNotHighlighted])

        highlighterState.backtrack(with: .string, length: 0)
        XCTAssertEqual(characterStyles.style(at: 3), .comment)
    }

    /// Backtracking further than the start of the text changes the styles back to it
    func testBacktrackingPastTheStart() {
        let highlighterState = highlighterState("abcdef")
        highlighterState.startLine(0, at: 0)
        highlighterState.position = 2
        highlighterState.backtrack(with: .property, length: 5)
        XCTAssertEqual((0..<6).map { characterStyles.style(at: $0) },
                       [.property, .property, .styleNotHighlighted, .styleNotHighlighted, .styleNotHighlighted,
                        .styleNotHighlighted])
    }

    // MARK: - Keywords

    /// Whether a keyword comes before the character before the position: at "-" with an offset of 1, before "(-"
    private func preceeded(_ string: String, by keyword: String = "Include", offset: Int32 = 1,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let highlighterState = highlighterState(string)
        let position = (string as NSString).range(of: "-").location
        XCTAssertNotEqual(position, NSNotFound, file: file, line: line)
        highlighterState.startLine(0, at: 0)
        highlighterState.position = position
        return highlighterState.preceeded(byKeyword: keyword, offset: offset)
    }

    /// A keyword counts in any case, and with spaces and tabs after it
    func testAKeywordBefore() {
        XCTAssertTrue(preceeded("Include (- Constant X; -)"))
        XCTAssertTrue(preceeded("Include(- Constant X; -)"))
        XCTAssertTrue(preceeded("INCLUDE \t (- Constant X; -)"))
        XCTAssertTrue(preceeded("Section 1\n\ninclude (- Constant X; -)"))
    }

    /// Nothing else can come between the keyword and the position
    func testSomethingElseBeforeTheKeyword() {
        XCTAssertFalse(preceeded("To go: (- Go(); -)"))
        XCTAssertFalse(preceeded("Include, (- Constant X; -)"))
        XCTAssertFalse(preceeded("Include\n(- Constant X; -)"))
        XCTAssertFalse(preceeded("Includes (- Constant X; -)"))
        XCTAssertFalse(preceeded("Inclu (- Constant X; -)"))
    }

    /// The offset is the number of characters between the keyword and the position, after the spaces and tabs
    func testTheOffset() {
        XCTAssertTrue(preceeded("Include -", offset: 0))
        XCTAssertFalse(preceeded("Include (-", offset: 0))
        XCTAssertTrue(preceeded("Include ((-", offset: 2))
    }

    /// At the start of the text, or with no room for the keyword before the position, nothing comes before it
    func testNoRoomForTheKeyword() {
        XCTAssertFalse(preceeded("-", offset: 0))
        XCTAssertFalse(preceeded("(-"))
        XCTAssertFalse(preceeded("  (-"))
        XCTAssertFalse(preceeded("ude (-"))
    }

    /// A keyword at the end of a longer word counts, as only what comes before the position is looked at
    func testAKeywordAtTheEndOfAWord() {
        XCTAssertTrue(preceeded("Reinclude (- Constant X; -)"))
    }
}
