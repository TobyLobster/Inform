//
//  IFPaneWidthsTests.swift
//  InformTests
//

import XCTest

/// How wide a project window's panes are laid out, the proportions kept for them, and how far a divider can be dragged
@MainActor
final class IFPaneWidthsTests: XCTestCase {
    private func widths(of count: Int,
                        in width: CGFloat,
                        divider: CGFloat = 3,
                        proportions: [Any]?) -> [Double] {
        return IFPaneWidths.widths(ofPanes: count,
                                   inWidth: width,
                                   dividerWidth: divider,
                                   proportions: proportions).map { $0.doubleValue }
    }

    // MARK: - Laying out the panes

    func testTwoPanesInEqualProportionsShareWhatTheDividerLeaves() {
        // 997 left: the first gets half, rounded down, and the last the rest
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [0.5, 0.5]), [498, 499])
    }

    func testTheProportionsAreOfEachOther() {
        // 997 left: the first gets a third, rounded down, and the last the rest
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [1, 2]), [332, 665])
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [0.25, 0.5]), [332, 665])
    }

    func testTheLastPaneHasWhatTheOthersAndTheDividersLeave() {
        XCTAssertEqual(widths(of: 3, in: 1000, divider: 5, proportions: [1, 1, 1]), [330, 330, 330])
        XCTAssertEqual(widths(of: 3, in: 1001, divider: 5, proportions: [1, 1, 1]), [330, 330, 331])
        XCTAssertEqual(widths(of: 3, in: 1000, divider: 5, proportions: [3, 1, 1]), [594, 198, 198])
    }

    func testAPaneAfterTheProportionsTakesTheLastOne() {
        XCTAssertEqual(widths(of: 3, in: 1000, divider: 5, proportions: [3, 1]), [594, 198, 198])
        XCTAssertEqual(widths(of: 3, in: 1000, divider: 5, proportions: [1]), [330, 330, 330])
    }

    func testAProportionThatIsntMoreThanNothingCountsAsOne() {
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [0, 1]), [498, 499])
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [-2, 1]), [498, 499])
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: [3, 0]), [747, 250])
    }

    func testWithNoProportionsThePanesAreTheSameWidth() {
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: nil), [498, 499])
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: []), [498, 499])
    }

    func testProportionsWrittenAsTextAreRead() {
        XCTAssertEqual(widths(of: 2, in: 1000, proportions: ["1", "2"]), [332, 665])
    }

    func testOnePaneHasAllTheWidth() {
        XCTAssertEqual(widths(of: 1, in: 1000, proportions: [0.5, 0.5]), [1000])
    }

    func testOnlyTheLastPaneCanHaveAFraction() {
        XCTAssertEqual(widths(of: 2, in: 1000.5, proportions: [1, 1]), [498, 499.5])
    }

    // MARK: - Keeping the proportions

    func testTheProportionsKeptAreEachWidthOverTheWindows() {
        let proportions = IFPaneWidths.proportions(ofWidths: [498, 499], inWindowWidth: 1000)
        XCTAssertEqual(proportions.map { $0.doubleValue }, [0.498, 0.499])
    }

    func testThePanesAreLaidOutAgainAsTheyWereKept() {
        for (width, proportions) in [(1000.0, [1.0, 2.0]), (1440, [0.62, 0.38]), (1203, [0.3, 0.7])] {
            let laidOut = widths(of: 2, in: width, proportions: proportions)
            let kept = IFPaneWidths.proportions(ofWidths: laidOut.map { NSNumber(value: $0) },
                                                inWindowWidth: width)
            XCTAssertEqual(widths(of: 2, in: width, proportions: kept), laidOut, "\(width) wide")
        }
    }

    func testThePanesCanBeLaidOutAgainAPointDifferent() {
        // The first pane is 119.7 wide, so 119; kept as 119/402 of the window, it's then 118.9999…, so 118, and
        // stays so
        let laidOut = widths(of: 2, in: 402, proportions: [0.3, 0.7])
        XCTAssertEqual(laidOut, [119, 280])

        var kept = IFPaneWidths.proportions(ofWidths: laidOut.map { NSNumber(value: $0) }, inWindowWidth: 402)
        let again = widths(of: 2, in: 402, proportions: kept)
        XCTAssertEqual(again, [118, 281])

        kept = IFPaneWidths.proportions(ofWidths: again.map { NSNumber(value: $0) }, inWindowWidth: 402)
        XCTAssertEqual(widths(of: 2, in: 402, proportions: kept), [118, 281])
    }

    // MARK: - Dragging a divider

    func testADividerLeavesThePaneBeforeItAtLeast75Wide() {
        XCTAssertEqual(IFPaneWidths.leastDividerPosition(10), 75)
        XCTAssertEqual(IFPaneWidths.leastDividerPosition(75), 75)
        XCTAssertEqual(IFPaneWidths.leastDividerPosition(300), 300)
    }

    func testADividerLeavesThePaneAfterItAtLeast75Wide() {
        XCTAssertEqual(IFPaneWidths.greatestDividerPosition(600, inWidth: 1000), 600)
        XCTAssertEqual(IFPaneWidths.greatestDividerPosition(950, inWidth: 1000), 925)
    }

    func testInANarrowSplitViewADividerCanGoTo75() {
        XCTAssertEqual(IFPaneWidths.greatestDividerPosition(100, inWidth: 120), 75)
        XCTAssertEqual(IFPaneWidths.greatestDividerPosition(60, inWidth: 120), 60)
    }
}
