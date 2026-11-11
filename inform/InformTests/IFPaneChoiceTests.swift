//
//  IFPaneChoiceTests.swift
//  InformTests
//

import XCTest

/// Which of a project window's panes to show the source, the documentation and the index in, from what each is
/// showing, and which pane is opposite another
@MainActor
final class IFPaneChoiceTests: XCTestCase {
    private func numbers(_ views: [IFProjectPaneType]) -> [NSNumber] {
        return views.map { NSNumber(value: $0.rawValue) }
    }

    private func sourcePane(_ views: IFProjectPaneType...) -> Int {
        return IFPaneChoice.sourcePane(forViews: numbers(views))
    }

    private func auxPane(_ views: IFProjectPaneType...) -> Int {
        return IFPaneChoice.auxPane(forViews: numbers(views))
    }

    private func indexPane(_ views: IFProjectPaneType...) -> Int {
        return IFPaneChoice.indexPane(forViews: numbers(views))
    }

    // MARK: - The source

    func testTheSourceGoesInTheFirstPaneShowingIt() {
        XCTAssertEqual(sourcePane(.sourcePane, .sourcePane), 0)
        XCTAssertEqual(sourcePane(.sourcePane, .gamePane), 0)
        XCTAssertEqual(sourcePane(.gamePane, .sourcePane), 1)
        XCTAssertEqual(sourcePane(.errorPane, .sourcePane), 1)
        XCTAssertEqual(sourcePane(.sourcePane, .errorPane), 0)
    }

    func testWithNoSourceShowingItGoesInThePaneAfterTheLastShowingErrors() {
        XCTAssertEqual(sourcePane(.errorPane, .gamePane), 1)
        XCTAssertEqual(sourcePane(.errorPane, .documentationPane), 1)
        XCTAssertEqual(sourcePane(.errorPane, .errorPane, .gamePane), 2)
        XCTAssertEqual(sourcePane(.errorPane, .gamePane, .indexPane), 1)
    }

    func testWhenTheLastPaneShowsErrorsTheSourceGoesInTheFirst() {
        XCTAssertEqual(sourcePane(.gamePane, .errorPane), 0)
        XCTAssertEqual(sourcePane(.errorPane, .errorPane), 0)
        // Even when the first shows errors too, and another doesn't. The app's windows have two panes
        XCTAssertEqual(sourcePane(.errorPane, .gamePane, .errorPane), 0)
    }

    func testWithNoSourceOrErrorsShowingTheSourceGoesInTheFirstPane() {
        XCTAssertEqual(sourcePane(.gamePane, .documentationPane), 0)
        XCTAssertEqual(sourcePane(.indexPane, .skeinPane), 0)
        XCTAssertEqual(sourcePane(.extensionsPane, .gamePane), 0)
    }

    func testWithOnePaneOrNoneTheSourceGoesInTheFirst() {
        XCTAssertEqual(sourcePane(.errorPane), 0)
        XCTAssertEqual(sourcePane(.gamePane), 0)
        XCTAssertEqual(sourcePane(), 0)
    }

    // MARK: - The documentation and the like

    func testTheDocumentationGoesInTheFirstPaneShowingIt() {
        XCTAssertEqual(auxPane(.documentationPane, .sourcePane), 0)
        XCTAssertEqual(auxPane(.sourcePane, .documentationPane), 1)
        XCTAssertEqual(auxPane(.documentationPane, .documentationPane), 0)
        // Rather than the last pane showing something else
        XCTAssertEqual(auxPane(.documentationPane, .indexPane), 0)
    }

    func testWithNoDocumentationShowingItGoesInTheLastPaneShowingAnythingButTheSourceOrGame() {
        XCTAssertEqual(auxPane(.indexPane, .skeinPane), 1)
        XCTAssertEqual(auxPane(.skeinPane, .gamePane), 0)
        XCTAssertEqual(auxPane(.errorPane, .sourcePane), 0)
        XCTAssertEqual(auxPane(.sourcePane, .errorPane), 1)
        XCTAssertEqual(auxPane(.extensionsPane, .sourcePane), 0)
        XCTAssertEqual(auxPane(.indexPane, .sourcePane, .gamePane), 0)
    }

    func testWithOnlyTheSourceAndGameShowingItGoesInThePaneAfterTheFirstShowingTheSource() {
        XCTAssertEqual(auxPane(.sourcePane, .gamePane), 1)
        XCTAssertEqual(auxPane(.sourcePane, .sourcePane), 1)
        XCTAssertEqual(auxPane(.gamePane, .sourcePane, .gamePane), 2)
        XCTAssertEqual(auxPane(.sourcePane, .sourcePane, .sourcePane), 1)
    }

    func testWhenTheLastPaneIsTheFirstShowingTheSourceItGoesInTheFirstPane() {
        XCTAssertEqual(auxPane(.gamePane, .sourcePane), 0)
        XCTAssertEqual(auxPane(.gamePane, .gamePane, .sourcePane), 0)
        XCTAssertEqual(auxPane(.sourcePane), 0)
    }

    func testWithOnlyTheGameShowingItGoesInTheSecondPane() {
        XCTAssertEqual(auxPane(.gamePane, .gamePane), 1)
        XCTAssertEqual(auxPane(.gamePane, .gamePane, .gamePane), 1)
    }

    func testWithOnePaneOrNoneTheDocumentationGoesInTheFirst() {
        XCTAssertEqual(auxPane(.gamePane), 0)
        XCTAssertEqual(auxPane(.indexPane), 0)
        XCTAssertEqual(auxPane(), 0)
    }

    // MARK: - The index

    func testTheIndexGoesInTheFirstPaneShowingIt() {
        XCTAssertEqual(indexPane(.indexPane, .sourcePane), 0)
        XCTAssertEqual(indexPane(.sourcePane, .indexPane), 1)
        XCTAssertEqual(indexPane(.indexPane, .indexPane), 0)
        // Rather than a pane showing the documentation
        XCTAssertEqual(indexPane(.documentationPane, .indexPane), 1)
    }

    func testWithNoIndexShowingItGoesWhereTheDocumentationWould() {
        XCTAssertEqual(indexPane(.documentationPane, .sourcePane), 0)
        XCTAssertEqual(indexPane(.sourcePane, .gamePane), 1)
        XCTAssertEqual(indexPane(.gamePane, .sourcePane), 0)
        XCTAssertEqual(indexPane(.skeinPane, .gamePane), 0)
        XCTAssertEqual(indexPane(.gamePane, .gamePane), 1)
        XCTAssertEqual(indexPane(), 0)
    }

    // MARK: - The opposite pane

    func testThePaneOppositeAnotherIsTheOneBeforeIt() {
        XCTAssertEqual(IFPaneChoice.paneOppositePane(1, count: 2), 0)
        XCTAssertEqual(IFPaneChoice.paneOppositePane(2, count: 3), 1)
        XCTAssertEqual(IFPaneChoice.paneOppositePane(1, count: 3), 0)
    }

    func testThePaneOppositeTheFirstIsTheLast() {
        XCTAssertEqual(IFPaneChoice.paneOppositePane(0, count: 2), 1)
        XCTAssertEqual(IFPaneChoice.paneOppositePane(0, count: 3), 2)
        XCTAssertEqual(IFPaneChoice.paneOppositePane(0, count: 1), 0)
    }
}
