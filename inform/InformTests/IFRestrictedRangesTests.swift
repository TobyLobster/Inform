//
//  IFRestrictedRangesTests.swift
//  InformTests
//

import XCTest

/// Keeping the range of a text that a view shows in step with edits to the whole text.
@MainActor
final class IFRestrictedRangesTests: XCTestCase {

    /// The range the view shows: characters 10 to 14.
    private let range = NSRange(location: 10, length: 5)
    private let notFound = NSRange(location: NSNotFound, length: 0)

    /// Where the range is after an edit replacing some characters with others.
    private func adjusted(replacing location: Int, _ length: Int, with count: Int) -> NSRange {
        IFRestrictedRanges.adjust(range,
                                  editedRange: NSRange(location: location, length: count),
                                  changeInLength: count - length)
    }

    /// The part of an edited range within the range.
    private func intersection(_ location: Int, _ length: Int) -> NSRange {
        IFRestrictedRanges.intersect(NSRange(location: location, length: length), withRestrictedRange: range)
    }

    // MARK: - Adjusting the range

    func testAnEditAfterTheRangeLeavesIt() {
        XCTAssertEqual(adjusted(replacing: 20, 2, with: 5), range)
        XCTAssertEqual(adjusted(replacing: 16, 2, with: 0), range)
    }

    func testAnEditBeforeTheRangeMovesIt() {
        XCTAssertEqual(adjusted(replacing: 2, 0, with: 3), NSRange(location: 13, length: 5))
        XCTAssertEqual(adjusted(replacing: 2, 4, with: 0), NSRange(location: 6, length: 5))
        XCTAssertEqual(adjusted(replacing: 2, 4, with: 1), NSRange(location: 7, length: 5))
    }

    func testAnEditEndingAtTheStartOfTheRangeMovesIt() {
        XCTAssertEqual(adjusted(replacing: 8, 2, with: 0), NSRange(location: 8, length: 5))
        XCTAssertEqual(adjusted(replacing: 8, 2, with: 3), NSRange(location: 11, length: 5))
    }

    func testInsertingWithinTheRangeLengthensIt() {
        XCTAssertEqual(adjusted(replacing: 12, 0, with: 3), NSRange(location: 10, length: 8))
    }

    func testInsertingAtTheStartOrEndOfTheRangeLengthensIt() {
        XCTAssertEqual(adjusted(replacing: 10, 0, with: 2), NSRange(location: 10, length: 7))
        XCTAssertEqual(adjusted(replacing: 15, 0, with: 2), NSRange(location: 10, length: 7))
    }

    func testDeletingWithinTheRangeShortensIt() {
        XCTAssertEqual(adjusted(replacing: 11, 2, with: 0), NSRange(location: 10, length: 3))
    }

    func testDeletingAcrossTheStartOrEndOfTheRange() {
        XCTAssertEqual(adjusted(replacing: 8, 4, with: 0), NSRange(location: 8, length: 3))
        XCTAssertEqual(adjusted(replacing: 13, 5, with: 0), NSRange(location: 10, length: 3))
    }

    func testDeletingTheRange() {
        XCTAssertEqual(adjusted(replacing: 10, 5, with: 0), NSRange(location: 10, length: 0))
        XCTAssertEqual(adjusted(replacing: 8, 10, with: 0), NSRange(location: 8, length: 0))
    }

    /// What replaces text across the start of the range goes before it; across its end, into it.
    func testReplacingAcrossTheStartOrEndOfTheRange() {
        XCTAssertEqual(adjusted(replacing: 8, 4, with: 6), NSRange(location: 14, length: 3))
        XCTAssertEqual(adjusted(replacing: 13, 5, with: 2), NSRange(location: 10, length: 5))
    }

    func testReplacingTheRange() {
        XCTAssertEqual(adjusted(replacing: 10, 5, with: 3), NSRange(location: 10, length: 3))
        XCTAssertEqual(adjusted(replacing: 8, 10, with: 3), NSRange(location: 11, length: 0))
    }

    // MARK: - The part of an edit in the range

    func testAnEditWithinTheRange() {
        XCTAssertEqual(intersection(11, 2), NSRange(location: 11, length: 2))
        XCTAssertEqual(intersection(10, 5), range)
        XCTAssertEqual(intersection(12, 0), NSRange(location: 12, length: 0))
    }

    func testAnEditOverTheRange() {
        XCTAssertEqual(intersection(8, 10), range)
    }

    func testAnEditAcrossTheStartOrEndOfTheRange() {
        XCTAssertEqual(intersection(8, 4), NSRange(location: 10, length: 2))
        XCTAssertEqual(intersection(13, 5), NSRange(location: 13, length: 2))
    }

    func testAnEditBeforeOrAfterTheRangeIsNotInIt() {
        XCTAssertEqual(intersection(2, 3), notFound)
        XCTAssertEqual(intersection(9, 0), notFound)
        XCTAssertEqual(intersection(16, 0), notFound)
        XCTAssertEqual(intersection(20, 1), notFound)
    }

    func testAnEditTouchingTheStartOrEndOfTheRangeMeetsItInNothing() {
        XCTAssertEqual(intersection(8, 2), NSRange(location: 10, length: 0))
        XCTAssertEqual(intersection(10, 0), NSRange(location: 10, length: 0))
        XCTAssertEqual(intersection(15, 0), NSRange(location: 15, length: 0))
        XCTAssertEqual(intersection(15, 3), NSRange(location: 15, length: 0))
    }
}
