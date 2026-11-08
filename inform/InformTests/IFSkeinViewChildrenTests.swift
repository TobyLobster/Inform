//
//  IFSkeinViewChildrenTests.swift
//  InformTests
//

import XCTest

final class IFSkeinViewChildrenTests: XCTestCase {

    /// The height of an arrow's view: its head, with a point above and below
    private let arrowViewHeight = kSkeinArrowHeadHeight + 2.0

    private let skein: IFSkein = IFSkein(project: nil)
    private var window: NSWindow!
    /// A skein view with nothing laid out, so the only knots' views in it are the children's
    private var skeinView: IFSkeinView!
    private var children: IFSkeinViewChildren!

    override func setUp() {
        super.setUp()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        skeinView = IFSkeinView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        window.contentView?.addSubview(skeinView)
        children = IFSkeinViewChildren(skeinView: skeinView)
    }

    override func tearDown() {
        window.close()
        window = nil
        skeinView = nil
        children = nil
        super.tearDown()
    }

    private func add(_ command: String, to parent: IFSkeinItem, actual: String) -> IFSkeinItem {
        let item: IFSkeinItem = IFSkeinItem(skein: skein, command: command)
        item.actual = actual
        return parent.addChild(item)
    }

    /// A skein of three levels (a knot's children are in alphabetical order):
    ///
    ///     - start -
    ///     ├── look
    ///     │   └── north
    ///     └── wait
    private func makeSkein() -> (look: IFSkeinItem, north: IFSkeinItem, wait: IFSkeinItem) {
        skein.rootItem.actual = "Welcome\n>"
        let look = add("look", to: skein.rootItem, actual: "A room.\n>")
        let north = add("north", to: look, actual: "A hall.\n>")
        let wait = add("wait", to: skein.rootItem, actual: "Time passes.\n>")
        return (look, north, wait)
    }

    /// Lays out the skein in the skein view's layout, and the children's views to match, as the skein view does
    @discardableResult
    private func layOut(selecting selected: IFSkeinItem?, animate: Bool = false) -> IFSkeinLayout {
        let layout = skeinView.layoutTree
        layout.rootItem = skein.rootItem
        layout.activeItem = nil
        layout.selectedItem = selected
        layout.layoutSkein()
        children.updateReportDetails()
        layout.update(withReportDetails: children.reportDetails)
        children.update(with: layout, animate: animate)
        return layout
    }

    /// The layout items of the layout, keyed by their knots' ids
    private func layoutItems(_ layout: IFSkeinLayout) -> [UInt: IFSkeinLayoutItem] {
        var result: [UInt: IFSkeinLayoutItem] = [:]
        func add(_ item: IFSkeinLayoutItem) {
            result[item.item.uniqueId] = item
            item.children?.forEach(add)
        }
        if let root = layout.rootLayoutItem {
            add(root)
        }
        return result
    }

    /// The children's report, the one whose delegate they are
    private func report() throws -> IFSkeinReportView {
        return try XCTUnwrap(skeinView.subviews.compactMap { $0 as? IFSkeinReportView }
                                                .first { $0.delegate === children })
    }

    private func itemViews() -> [IFSkeinItemView] {
        return skeinView.subviews.compactMap { $0 as? IFSkeinItemView }
    }

    private func linkViews() -> [NSView] {
        return skeinView.subviews.filter { NSStringFromClass(type(of: $0)).hasSuffix("IFSkeinLinkView") }
    }

    private func arrowViews() -> [IFSkeinArrowView] {
        return skeinView.subviews.compactMap { $0 as? IFSkeinArrowView }
    }

    private func opacity(_ view: NSView) throws -> Float {
        return try XCTUnwrap(view.layer).opacity
    }

    // MARK: - New children

    /// New children add a report to the skein view, and have no knots' views
    func testNewChildren() throws {
        XCTAssertEqual(skeinView.subviews.filter { $0 is IFSkeinReportView }.count, 2, "the skein view's own, too")
        let report = try report()
        XCTAssertIdentical(skeinView.subviews.last, report)
        XCTAssertEqual(children.reportDetails, [])
        XCTAssertNil(children.layoutItem(for: skein.rootItem))
        XCTAssertNil(children.itemView(for: skein.rootItem))
        XCTAssertEqual(children.rect(for: skein.rootItem), .zero)
    }

    /// The children don't keep their skein view, which keeps them, so a skein view is freed once nothing else keeps
    /// it, with its knots' views
    func testTheSkeinViewIsntKept() {
        let (_, north, _) = makeSkein()
        weak var weakView: IFSkeinView?
        weak var weakItemView: IFSkeinItemView?
        autoreleasepool {
            let view = IFSkeinView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
            view.skein = skein
            view.select(north, withAnimation: false)
            weakView = view
            weakItemView = view.subviews.compactMap { $0 as? IFSkeinItemView }.first
            XCTAssertNotNil(weakItemView)
        }
        XCTAssertNil(weakView)
        XCTAssertNil(weakItemView)
    }

    // MARK: - The knots' views

    /// Each knot has a view where its layout item is, a link to its parent (but for the start) and an arrow
    func testTheViews() throws {
        let (look, north, wait) = makeSkein()
        let layout = layOut(selecting: north)
        let items = layoutItems(layout)
        XCTAssertEqual(items.count, 4)

        for knot in [skein.rootItem, look, north, wait] {
            let layoutItem = try XCTUnwrap(items[knot.uniqueId])
            let itemView = try XCTUnwrap(children.itemView(for: knot))
            XCTAssertIdentical(itemView.superview, skeinView)
            XCTAssertEqual(itemView.frame, layoutItem.boundingRect)
            XCTAssertIdentical(itemView.layoutItem, layoutItem)
            XCTAssertIdentical(children.layoutItem(for: knot), layoutItem)
            XCTAssertEqual(try opacity(itemView), 1)
        }
        XCTAssertEqual(itemViews().count, 4)
        XCTAssertEqual(linkViews().count, 3)
        XCTAssertEqual(arrowViews().count, 4)
    }

    /// The links are below the arrows, the arrows below the knots, and the knots below the reports
    func testTheOrderOfTheViews() throws {
        let (_, north, _) = makeSkein()
        layOut(selecting: north)

        func kind(_ view: NSView) -> Int {
            switch view {
            case is IFSkeinReportView: return 3
            case is IFSkeinItemView:   return 2
            case is IFSkeinArrowView:  return 1
            default:                   return 0
            }
        }
        let kinds = skeinView.subviews.map(kind)
        XCTAssertEqual(kinds, kinds.sorted())
        XCTAssertEqual(kinds, [0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3])
    }

    /// Each knot on the selected line has an arrow from its right to the report, and the others' are hidden
    func testTheArrows() throws {
        let (look, north, wait) = makeSkein()
        let layout = layOut(selecting: north)
        let items = layoutItems(layout)

        let shown = try arrowViews().filter { try opacity($0) == 1 }
        XCTAssertEqual(Set(shown.map(\.frame.origin.y)).count, 3)
        for knot in [skein.rootItem, look, north] {
            let lozenge = try XCTUnwrap(items[knot.uniqueId]).lozengeRect
            let frame = NSRect(x: lozenge.maxX, y: floor(lozenge.midY - arrowViewHeight * 0.5),
                               width: layout.reportPosition.x - lozenge.maxX, height: arrowViewHeight)
            XCTAssertTrue(shown.contains { $0.frame == frame }, knot.command)
        }

        let hidden = try arrowViews().filter { try opacity($0) == 0 }
        XCTAssertEqual(hidden.count, 1)
        XCTAssertEqual(hidden.first?.frame, .zero, "the arrow for wait was never placed")

        // Selecting another line moves the arrows
        layOut(selecting: wait)
        XCTAssertEqual(try arrowViews().filter { try opacity($0) == 1 }.count, 2)
    }

    /// Re-laying out the skein keeps each knot's views, and moves them
    func testLayingOutAgain() throws {
        let (look, north, _) = makeSkein()
        layOut(selecting: north)
        let lookView = try XCTUnwrap(children.itemView(for: look))
        let views = Set(skeinView.subviews.map(ObjectIdentifier.init))

        // A knot that comes before "look" moves it right
        _ = add("examine", to: skein.rootItem, actual: "Nothing special.\n>")
        let layout = layOut(selecting: north)
        XCTAssertIdentical(children.itemView(for: look), lookView)
        XCTAssertEqual(lookView.frame, try XCTUnwrap(layoutItems(layout)[look.uniqueId]).boundingRect)
        XCTAssertTrue(views.isSubset(of: Set(skeinView.subviews.map(ObjectIdentifier.init))))
        XCTAssertEqual(itemViews().count, 5)
        XCTAssertEqual(linkViews().count, 4)
        XCTAssertEqual(arrowViews().count, 5)
    }

    /// A knot that's no longer in the skein loses its views
    func testRemovingAKnot() throws {
        let (_, north, wait) = makeSkein()
        layOut(selecting: north)
        let waitView = try XCTUnwrap(children.itemView(for: wait))

        wait.removeFromParent()
        layOut(selecting: north)
        XCTAssertNil(waitView.superview)
        XCTAssertNil(children.itemView(for: wait))
        XCTAssertNil(children.layoutItem(for: wait))
        XCTAssertEqual(itemViews().count, 3)
        XCTAssertEqual(linkViews().count, 2)
        XCTAssertEqual(arrowViews().count, 3)
    }

    /// Animated, the knots and links that move are animated there, and the new knot's views simply appear
    func testAnimating() throws {
        let (look, north, wait) = makeSkein()
        layOut(selecting: north)
        let lookView = try XCTUnwrap(children.itemView(for: look))
        let waitView = try XCTUnwrap(children.itemView(for: wait))

        let examine = add("examine", to: skein.rootItem, actual: "Nothing special.\n>")
        layOut(selecting: north, animate: true)
        XCTAssertNotNil(lookView.layer?.animation(forKey: "positionItemAnimation"))
        let examineView = try XCTUnwrap(children.itemView(for: examine))
        XCTAssertNil(examineView.layer?.animation(forKey: "positionItemAnimation"))
        XCTAssertNil(examineView.layer?.animation(forKey: "opacity"))
        XCTAssertEqual(try opacity(examineView), 1)
        XCTAssertTrue(linkViews().contains { $0.layer?.animation(forKey: "groupLinkAnimation") != nil })

        // A knot that doesn't move isn't animated
        lookView.layer?.removeAllAnimations()
        waitView.layer?.removeAllAnimations()
        layOut(selecting: north, animate: true)
        XCTAssertNil(lookView.layer?.animation(forKey: "positionItemAnimation"))
        XCTAssertNil(waitView.layer?.animation(forKey: "positionItemAnimation"))
    }

    // MARK: - The report

    /// The report is where the layout puts it while a knot is selected, and hidden while none is
    func testTheReport() throws {
        let (_, north, _) = makeSkein()
        let layout = layOut(selecting: north)
        let report = try report()

        XCTAssertEqual(report.frame.origin, layout.reportPosition)
        XCTAssertEqual(report.frame.size.width, kSkeinReportWidth)
        XCTAssertGreaterThan(report.frame.size.height, 0)
        XCTAssertEqual(try opacity(report), 1)
        XCTAssertIdentical(report.rootTree, layout.rootLayoutItem)
        XCTAssertEqual(children.reportDetails.count, 3)
        XCTAssertEqual(children.reportDetails, report.reportDetails as? [NSNumber])

        layOut(selecting: nil)
        XCTAssertEqual(report.frame, .zero)
        XCTAssertEqual(try opacity(report), 0)
        XCTAssertEqual(children.reportDetails, [])
    }

    /// A knot's rectangle is its view's, and for a knot on the selected line, takes in its entry in the report too
    func testTheRectangleForAKnot() throws {
        let (look, north, wait) = makeSkein()
        layOut(selecting: north)
        let report = try report()

        let waitView = try XCTUnwrap(children.itemView(for: wait))
        XCTAssertEqual(children.rect(for: wait), waitView.frame)

        let lookView = try XCTUnwrap(children.itemView(for: look))
        let lookItem = try XCTUnwrap(lookView.layoutItem)
        let entry = report.rect(for: lookItem).offsetBy(dx: report.frame.minX, dy: report.frame.minY)
        XCTAssertNotEqual(entry, .zero)
        XCTAssertEqual(children.rect(for: look), lookView.frame.union(entry))

        let elsewhere: IFSkeinItem = IFSkeinItem(skein: skein, command: "jump")
        XCTAssertEqual(children.rect(for: elsewhere), .zero)
    }

    // MARK: - Blessing

    /// Blessing a knot, from the report or the children, gives it its transcript as its ideal, and cursing takes
    /// its ideal away
    func testBlessing() throws {
        let (look, north, _) = makeSkein()
        layOut(selecting: north)
        XCTAssertEqual(look.ideal, "")

        let entry = try XCTUnwrap(try report().subviews.compactMap { $0 as? IFSkeinReportItemView }
                                                       .first { $0.uniqueId == look.uniqueId })
        let button = entry.blessButton
        NSApp.sendAction(try XCTUnwrap(button.action), to: button.target, from: button)
        XCTAssertEqual(look.ideal, look.actual)

        children.setItemBlessed(look, bless: false)
        XCTAssertEqual(look.ideal, "")
        children.setItemBlessed(look, bless: true)
        XCTAssertEqual(look.ideal, look.actual)
    }

    // MARK: - The font size

    /// After the font size changes, the report is laid out again the next time
    func testTheFontSize() throws {
        let (_, north, _) = makeSkein()
        layOut(selecting: north)
        let report = try report()
        XCTAssertFalse(report.forceResizeDueToFontSizeChange)

        children.fontSizePreferenceChanged()
        XCTAssertTrue(report.forceResizeDueToFontSizeChange)
        layOut(selecting: north)
        XCTAssertFalse(report.forceResizeDueToFontSizeChange)
    }
}
