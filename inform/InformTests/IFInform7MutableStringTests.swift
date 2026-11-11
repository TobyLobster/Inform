//
//  IFInform7MutableStringTests.swift
//  InformTests
//

import XCTest

/// Comment Out and Uncomment Selection, on source text with the selection marked by « and ».
@MainActor
final class IFInform7MutableStringTests: XCTestCase {

    /// Runs the change on the marked text, and returns the text with the range it gives back marked,
    /// or "unchanged" if it makes no change.
    private func change(_ marked: String,
                        _ action: (NSMutableString, UnsafeMutablePointer<NSRange>) -> Bool,
                        file: StaticString = #filePath, line: UInt = #line) -> String {
        let start = (marked as NSString).range(of: "«").location
        let end = (marked as NSString).range(of: "»").location
        let original = marked.replacingOccurrences(of: "«", with: "").replacingOccurrences(of: "»", with: "")
        let text = NSMutableString(string: original)
        var range = NSRange(location: start, length: end - start - 1)

        guard action(text, &range) else {
            XCTAssertEqual(text as String, original, file: file, line: line)
            return "unchanged"
        }
        text.insert("»", at: NSMaxRange(range))
        text.insert("«", at: range.location)
        return text as String
    }

    private func commentOut(_ marked: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        return change(marked, { $0.commentOutInform7($1) }, file: file, line: line)
    }

    private func uncomment(_ marked: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        return change(marked, { $0.removeCommentsInform7($1) }, file: file, line: line)
    }

    // MARK: - Comment Out

    func testCommentingOut() {
        XCTAssertEqual(commentOut("The Kitchen is a room.\n«Every turn: say \"Hi\".»\n"),
                       "The Kitchen is a room.\n«[Every turn: say \"Hi\".]»\n")
    }

    func testCommentingOutNothing() {
        XCTAssertEqual(commentOut("The Kitchen«» is a room."), "unchanged")
    }

    func testCommentingOutPartOfAComment() {
        XCTAssertEqual(commentOut("[A «note» here.]"), "[A «[note]» here.]")
    }

    func testCommentingOutInAString() {
        XCTAssertEqual(commentOut("say \"«Hi»\"."), "unchanged")
        XCTAssertEqual(commentOut("say “«Hi»”."), "unchanged")
    }

    func testCommentingOutAcrossAString() {
        XCTAssertEqual(commentOut("say «\"Hi».\""), "unchanged")
        XCTAssertEqual(commentOut("say \"«Hi\".»"), "unchanged")
    }

    func testCommentingOutAcrossTheStartOrEndOfAComment() {
        XCTAssertEqual(commentOut("A «note [Every» turn]"), "unchanged")
        XCTAssertEqual(commentOut("[A «note] Every» turn"), "unchanged")
    }

    func testBracketsInAStringAreNotComments() {
        XCTAssertEqual(commentOut("say \"[\". «Every turn» \"]\""), "say \"[\". «[Every turn]» \"]\"")
    }

    func testAQuotationMarkInACommentIsntAString() {
        // As the highlighter and Inform have it
        XCTAssertEqual(commentOut("[Use a \" for text.]\n«Every turn: say \"Hi\".»\n"),
                       "[Use a \" for text.]\n«[Every turn: say \"Hi\".]»\n")
        XCTAssertEqual(commentOut("[A «note with a “» here.]"), "[A «[note with a “]» here.]")
    }

    func testCommentingOutPastTheEndOfTheText() {
        let text = NSMutableString(string: "Every turn")
        var range = NSRange(location: 6, length: 100)
        XCTAssertTrue(text.commentOutInform7(&range))
        XCTAssertEqual(text as String, "Every [turn]")
        XCTAssertEqual(range, NSRange(location: 6, length: 6))
    }

    // MARK: - Uncomment

    func testUncommenting() {
        XCTAssertEqual(uncomment("The Kitchen is a room.\n«[Every turn: say \"Hi\".]»\n"),
                       "The Kitchen is a room.\n«Every turn: say \"Hi\".»\n")
    }

    func testUncommentingPartOfAComment() {
        // The comment is closed before the selection and opened again after it
        XCTAssertEqual(uncomment("[A «note» here.]"), "[A «]note[» here.]")
    }

    func testUncommentingAfterAQuotationMarkInAComment() {
        XCTAssertEqual(uncomment("[Use a \" for text.]\n«[Every turn: say \"Hi\".]»\n"),
                       "[Use a \" for text.]\n«Every turn: say \"Hi\".»\n")
        XCTAssertEqual(uncomment("[A «note with a \"» here.]"), "[A «]note with a \"[» here.]")
    }

    func testUncommentingWhatIsntAComment() {
        XCTAssertEqual(uncomment("«Every turn»"), "unchanged")
        XCTAssertEqual(uncomment("«»"), "unchanged")
        XCTAssertEqual(uncomment("say \"«[Hi]»\"."), "unchanged")
    }

    func testUncommentingAcrossTheStartOrEndOfAComment() {
        XCTAssertEqual(uncomment("«[A note» here.]"), "unchanged")
        XCTAssertEqual(uncomment("[A «note] Every» turn"), "unchanged")
    }

    func testUncommentingTwoComments() {
        // Not right: this takes the first and last brackets away, leaving the brackets between
        XCTAssertEqual(uncomment("«[A note] Every turn [another]»"), "«A note] Every turn [another»")
    }
}
