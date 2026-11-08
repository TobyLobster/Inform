//
//  IFSkeinReportViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinReportViewTests: XCTestCase {

    private let skein: IFSkein = IFSkein(project: nil)

    /// Records what the report tells its delegate
    private final class Recorder: NSObject, IFSkeinReportBlessDelegate {
        var blessed: [(item: IFSkeinItem, bless: Bool)] = []

        func setItemBlessed(_ item: IFSkeinItem, bless: Bool) {
            blessed.append((item, bless))
        }
    }

    /// A view that records the mouse events that reach it
    private final class MouseRecorder: NSView {
        var events: [String] = []

        override func mouseDown(with event: NSEvent) {
            events.append("down")
        }

        override func mouseUp(with event: NSEvent) {
            events.append("up")
        }

        override func mouseDragged(with event: NSEvent) {
            events.append("dragged")
        }
    }

    private func add(_ command: String, to parent: IFSkeinItem, actual: String, ideal: String = "") -> IFSkeinItem {
        let item: IFSkeinItem = IFSkeinItem(skein: skein, command: command)
        item.actual = actual
        item.ideal = ideal
        return parent.addChild(item)
    }

    /// A skein of three levels, with the opening, a knot with no ideal and a blessed knot:
    ///
    ///     - start -        "Welcome\n>"
    ///     └── look         "A room.\n>"
    ///         └── north    "A hall.\n>", blessed
    private func makeSkein() -> (look: IFSkeinItem, north: IFSkeinItem) {
        skein.rootItem.actual = "Welcome\n>"
        let look = add("look", to: skein.rootItem, actual: "A room.\n>")
        let north = add("north", to: look, actual: "A hall.\n>", ideal: "A hall.\n>")
        return (look, north)
    }

    /// The skein laid out as the skein view does it, with the line through the given knot selected: the line from
    /// the start to the knot, and on through each knot's first child
    private func layOut(selecting selected: IFSkeinItem?) -> IFSkeinLayoutItem? {
        let layout = IFSkeinLayout(rootItem: skein.rootItem)
        layout.selectedItem = selected
        layout.layoutSkein()
        return layout.rootLayoutItem
    }

    /// A report on the line through the given knot
    private func makeReport(selecting selected: IFSkeinItem?) -> IFSkeinReportView {
        let report = IFSkeinReportView()
        report.rootTree = layOut(selecting: selected)
        report.updateReportDetails()
        return report
    }

    /// The report's entries, from the top
    private func entries(_ report: IFSkeinReportView) -> [IFSkeinReportItemView] {
        return report.subviews.compactMap { $0 as? IFSkeinReportItemView }.sorted { $0.frame.minY > $1.frame.minY }
    }

    private func text(_ entry: IFSkeinReportItemView) throws -> NSAttributedString {
        return try XCTUnwrap(entry.textView.textStorage)
    }

    /// The text of the runs in the text that have the given attribute
    private func runs(_ text: NSAttributedString, with key: NSAttributedString.Key) -> [String] {
        var result: [String] = []
        text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil {
                result.append(text.attributedSubstring(from: range).string)
            }
        }
        return result
    }

    /// The heights of the report's levels, from the top
    private func details(_ report: IFSkeinReportView) -> [Double] {
        return report.reportDetails.map { ($0 as! NSNumber).doubleValue }
    }

    private var fontSize: CGFloat {
        return kSkeinDefaultReportFontSize * IFPreferences.shared.appFontSizeMultiplier
    }

    private func mouseEvent(_ type: NSEvent.EventType) throws -> NSEvent {
        return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                                                windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1,
                                                pressure: 1))
    }

    // MARK: - A new report

    func testANewReport() {
        let report = IFSkeinReportView()
        XCTAssertEqual(report.frame, .zero)
        XCTAssertEqual(report.subviews, [])
        XCTAssertEqual(details(report), [])
        XCTAssertNil(report.rootTree)
        XCTAssertNil(report.delegate)
        XCTAssertTrue(report.forceResizeDueToFontSizeChange)
        XCTAssertTrue(report.wantsLayer)
    }

    /// With nothing laid out, the report is empty, and as wide as a report
    func testNoSkein() {
        let report = IFSkeinReportView()
        report.updateReportDetails()
        XCTAssertEqual(report.subviews, [])
        XCTAssertEqual(details(report), [])
        XCTAssertEqual(report.frame, NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: 0))
        XCTAssertFalse(report.forceResizeDueToFontSizeChange)
    }

    // MARK: - The entries

    /// An entry for each knot on the selected line, the start at the top, each with a bless button for its knot
    func testTheEntries() throws {
        let (look, north) = makeSkein()
        let report = makeReport(selecting: north)

        let entries = entries(report)
        XCTAssertEqual(entries.map(\.uniqueId), [skein.rootItem.uniqueId, look.uniqueId, north.uniqueId])
        for entry in entries {
            XCTAssertIdentical(entry.blessButton.target, report)
            XCTAssertEqual(entry.blessButton.action, NSSelectorFromString("blessButtonPressed:"))
            XCTAssertEqual(entry.blessButton.tag, Int(entry.uniqueId))
        }
        // A tick for a knot whose transcript differs from its ideal, and a cross for one whose doesn't
        XCTAssertEqual(entries.map(\.blessButton.blessState), [true, true, false])
        XCTAssertFalse(report.forceResizeDueToFontSizeChange)
    }

    /// The entries are stacked from the bottom, the selected knot's first, each at least a level of the skein high,
    /// with a gap for a separator between them, and the report is as tall as them. The heights of the levels are
    /// kept, from the top, for the skein to lay out its levels to match.
    func testTheEntriesHeights() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        let entries = entries(report)
        XCTAssertEqual(entries.count, 3)

        // Below the separator: a gap and the line
        let separator = kDottedSeparatorGapAboveLine + kDottedSeparatorLineThickness
        let leafStride = max(kSkeinMinLevelHeight,
                             kDottedSeparatorGapBelowLine + entries[2].textHeight + kSkeinReportInsideBottomBorder)
        let middleStride = max(kSkeinMinLevelHeight,
                               kDottedSeparatorGapBelowLine + entries[1].textHeight + separator)
        let rootStride = max(kSkeinMinLevelHeight,
                             kSkeinReportInsideTopBorder + entries[0].textHeight + separator)

        XCTAssertEqual(entries.map(\.topBorderHeight),
                       [kSkeinReportInsideTopBorder, kDottedSeparatorGapBelowLine, kDottedSeparatorGapBelowLine])
        XCTAssertEqual(entries[2].frame,
                       NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: leafStride - kDottedSeparatorLineThickness))
        XCTAssertEqual(entries[1].frame,
                       NSRect(x: 0, y: leafStride, width: kSkeinReportWidth,
                              height: middleStride - kDottedSeparatorLineThickness))
        XCTAssertEqual(entries[0].frame,
                       NSRect(x: 0, y: leafStride + middleStride, width: kSkeinReportWidth,
                              height: rootStride - kDottedSeparatorLineThickness))
        XCTAssertEqual(report.frame,
                       NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: leafStride + middleStride + rootStride))

        // The top level's height is as if it had a separator above it
        let rootLevel = rootStride - kSkeinReportInsideTopBorder + kDottedSeparatorGapBelowLine
        XCTAssertEqual(details(report), [rootLevel, middleStride, leafStride].map(Double.init))
    }

    /// With only the start on the selected line, its entry has the report's borders above and below it
    func testOnlyTheStart() throws {
        skein.rootItem.actual = "Welcome\n>"
        let report = makeReport(selecting: skein.rootItem)
        let entries = entries(report)
        XCTAssertEqual(entries.map(\.uniqueId), [skein.rootItem.uniqueId])

        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.topBorderHeight, kSkeinReportInsideTopBorder)
        let stride = max(kSkeinMinLevelHeight,
                         kSkeinReportInsideTopBorder + entry.textHeight + kSkeinReportInsideBottomBorder)
        XCTAssertEqual(entry.frame,
                       NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: stride - kDottedSeparatorLineThickness))
        XCTAssertEqual(report.frame.size, NSSize(width: kSkeinReportWidth, height: stride))
        XCTAssertEqual(details(report), [Double(stride - kSkeinReportInsideTopBorder + kDottedSeparatorGapBelowLine)])
    }

    /// A long transcript makes its entry taller than a level of the skein
    func testALongTranscript() throws {
        let (look, _) = makeSkein()
        let long = String(repeating: "A long line of output. ", count: 20)
        let wait = add("wait", to: look, actual: long + "\n>")
        let report = makeReport(selecting: wait)

        let entry = try XCTUnwrap(entries(report).last)
        XCTAssertEqual(entry.uniqueId, wait.uniqueId)
        XCTAssertGreaterThan(entry.textHeight, kSkeinMinLevelHeight)
        XCTAssertEqual(entry.frame.height,
                       kDottedSeparatorGapBelowLine + entry.textHeight + kSkeinReportInsideBottomBorder
                       - kDottedSeparatorLineThickness)
    }

    // MARK: - The transcripts

    /// Each entry has its knot's command, in bold, and its transcript. The start has no command.
    func testTheTranscripts() throws {
        let (_, north) = makeSkein()
        let entries = entries(makeReport(selecting: north))

        let texts = try entries.map { try text($0) }
        XCTAssertEqual(texts.map(\.string), ["Welcome", "look\nA room.", "north\nA hall."])

        let bold = NSFont.boldSystemFont(ofSize: fontSize)
        let normal = NSFont.systemFont(ofSize: fontSize)
        XCTAssertEqual(texts[1].attribute(.font, at: 0, effectiveRange: nil) as? NSFont, bold)
        XCTAssertEqual(texts[1].attribute(.font, at: 4, effectiveRange: nil) as? NSFont, bold, "the new line")
        XCTAssertEqual(texts[1].attribute(.font, at: 5, effectiveRange: nil) as? NSFont, normal)
        XCTAssertEqual(texts[2].attribute(.font, at: 0, effectiveRange: nil) as? NSFont, bold)
        XCTAssertEqual(texts[2].attribute(.font, at: 6, effectiveRange: nil) as? NSFont, normal)
        XCTAssertEqual(texts[0].attribute(.font, at: 0, effectiveRange: nil) as? NSFont, normal)
    }

    /// A transcript with no ideal is shown as inserted, on green, and one that matches its ideal plainly
    func testInsertedText() throws {
        let (_, north) = makeSkein()
        let texts = try entries(makeReport(selecting: north)).map { try text($0) }

        let green = NSColor(calibratedRed: 0.0, green: 0.75, blue: 0.0, alpha: 0.45)
        XCTAssertEqual(runs(texts[0], with: .backgroundColor), ["Welcome"])
        XCTAssertEqual(runs(texts[1], with: .backgroundColor), ["A room."])
        XCTAssertEqual(texts[1].attribute(.backgroundColor, at: 5, effectiveRange: nil) as? NSColor, green)
        XCTAssertEqual(runs(texts[1], with: .strikethroughStyle), [])
        XCTAssertEqual(runs(texts[2], with: .backgroundColor), [])
    }

    /// Where a transcript differs from its ideal, what the ideal has and it doesn't is struck through on red, and what
    /// it has and the ideal doesn't is on green, with what they share plain
    func testDeletedText() throws {
        let (look, _) = makeSkein()
        let take = add("take lamp", to: look, actual: "You can't see any such thing.\n>", ideal: "Taken.\n>")
        let text = try text(try XCTUnwrap(entries(makeReport(selecting: take)).last))

        XCTAssertEqual(text.string, "take lamp\nTakenYou can't see any such thing.")
        XCTAssertEqual(runs(text, with: .strikethroughStyle), ["Taken"])
        XCTAssertEqual(runs(text, with: .backgroundColor), ["Taken", "You can't see any such thing"])
        let inserted = (text.string as NSString).range(of: "You")
        XCTAssertEqual(text.attribute(.backgroundColor, at: inserted.location, effectiveRange: nil) as? NSColor,
                       NSColor(calibratedRed: 0.0, green: 0.75, blue: 0.0, alpha: 0.45))

        let deleted = (text.string as NSString).range(of: "Taken")
        let attributes = text.attributes(at: deleted.location, effectiveRange: nil)
        XCTAssertEqual(attributes[.backgroundColor] as? NSColor,
                       NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.1, alpha: 0.45))
        XCTAssertEqual(attributes[.strikethroughStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attributes[.strikethroughColor] as? NSColor,
                       NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
        XCTAssertEqual(attributes[.font] as? NSFont, NSFont.systemFont(ofSize: fontSize))
    }

    /// A prompt other than the standard one, at the end of the transcript before, is shown before the command
    func testAnotherPrompt() throws {
        let (look, _) = makeSkein()
        let question = add("ask", to: look, actual: "Who goes there?\nAnswer: ")
        let answer = add("friend", to: question, actual: "Pass, friend.\n>")
        let text = try text(try XCTUnwrap(entries(makeReport(selecting: answer)).last))

        XCTAssertEqual(text.string, "Answer: friend\nPass, friend.")
        XCTAssertEqual(text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont, NSFont.systemFont(ofSize: fontSize))
        XCTAssertEqual(text.attribute(.font, at: 8, effectiveRange: nil) as? NSFont,
                       NSFont.boldSystemFont(ofSize: fontSize))
    }

    // MARK: - Updating

    /// Updating again does nothing while the knots on the selected line are as they were
    func testUpdatingWithNoChange() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        let entry = try XCTUnwrap(entries(report).last)
        let frame = entry.frame

        entry.frame = .zero
        report.updateReportDetails()
        XCTAssertEqual(entry.frame, .zero)

        // A knot's transcript changes
        north.actual = "A long hall.\n>"
        report.updateReportDetails()
        XCTAssertEqual(entry.frame, frame)
        XCTAssertEqual(try text(entry).string, "north\nA long hall.")
    }

    /// After the font size changes, the report is laid out again, even with no change to the knots
    func testUpdatingAfterTheFontSize() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        let entry = try XCTUnwrap(entries(report).last)
        let frame = entry.frame

        entry.frame = .zero
        report.forceResizeDueToFontSizeChange = true
        report.updateReportDetails()
        XCTAssertEqual(entry.frame, frame)
        XCTAssertFalse(report.forceResizeDueToFontSizeChange)
    }

    /// Selecting a shorter line takes away the entries it doesn't need, and a longer one adds them
    func testAnotherLine() throws {
        let (look, north) = makeSkein()
        let wait = add("wait", to: skein.rootItem, actual: "Time passes.\n>")
        let report = makeReport(selecting: north)
        XCTAssertEqual(report.subviews.count, 3)

        report.rootTree = layOut(selecting: wait)
        report.updateReportDetails()
        XCTAssertEqual(entries(report).map(\.uniqueId), [skein.rootItem.uniqueId, wait.uniqueId])
        XCTAssertEqual(report.subviews.count, 2)
        XCTAssertEqual(details(report).count, 2)

        report.rootTree = layOut(selecting: north)
        report.updateReportDetails()
        XCTAssertEqual(entries(report).map(\.uniqueId), [skein.rootItem.uniqueId, look.uniqueId, north.uniqueId])
        XCTAssertEqual(report.subviews.count, 3)
    }

    /// Selecting nothing leaves the report empty
    func testNothingSelected() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)

        report.rootTree = layOut(selecting: nil)
        report.updateReportDetails()
        XCTAssertEqual(report.subviews, [])
        XCTAssertEqual(details(report), [])
        XCTAssertEqual(report.frame.size, NSSize(width: kSkeinReportWidth, height: 0))
    }

    // MARK: - Where the entries are

    /// The rectangle of a knot's entry is measured from the top of the report, and a knot with no entry has none
    func testTheRectangleForAKnot() throws {
        let (look, north) = makeSkein()
        let rootTree = try XCTUnwrap(layOut(selecting: north))
        let report = IFSkeinReportView()
        report.rootTree = rootTree
        report.updateReportDetails()

        let lookItem = try XCTUnwrap(rootTree.children?.first)
        XCTAssertIdentical(lookItem.item, look)
        let entry = try XCTUnwrap(entries(report).first { $0.uniqueId == look.uniqueId })
        XCTAssertEqual(report.rect(for: lookItem),
                       NSRect(x: 0, y: report.frame.height - entry.frame.maxY,
                              width: entry.frame.width, height: entry.frame.height))

        // The top entry is a separator's thickness below the top of the report
        let top = try XCTUnwrap(entries(report).first)
        XCTAssertEqual(report.rect(for: rootTree),
                       NSRect(x: 0, y: kDottedSeparatorLineThickness, width: top.frame.width, height: top.frame.height))

        let elsewhere = IFSkeinLayoutItem(item: add("wait", to: skein.rootItem, actual: ""), subtreeWidth: 0, level: 1)
        XCTAssertEqual(report.rect(for: elsewhere), .zero)
    }

    // MARK: - Blessing

    /// The bless button blesses a knot whose transcript differs from its ideal, and curses one whose doesn't, as it
    /// changes between a tick and a cross
    func testBlessing() throws {
        let (look, north) = makeSkein()
        let report = makeReport(selecting: north)
        let recorder = Recorder()
        report.delegate = recorder
        let entries = entries(report)

        let lookButton = entries[1].blessButton
        NSApp.sendAction(try XCTUnwrap(lookButton.action), to: lookButton.target, from: lookButton)
        XCTAssertFalse(lookButton.blessState)
        XCTAssertEqual(recorder.blessed.count, 1)
        XCTAssertIdentical(recorder.blessed.last?.item, look)
        XCTAssertEqual(recorder.blessed.last?.bless, true)

        let northButton = entries[2].blessButton
        NSApp.sendAction(try XCTUnwrap(northButton.action), to: northButton.target, from: northButton)
        XCTAssertTrue(northButton.blessState)
        XCTAssertEqual(recorder.blessed.count, 2)
        XCTAssertIdentical(recorder.blessed.last?.item, north)
        XCTAssertEqual(recorder.blessed.last?.bless, false)
    }

    /// Only a bless button for a knot on the selected line blesses it
    func testBlessingWithSomethingElse() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        let recorder = Recorder()
        report.delegate = recorder
        let action = NSSelectorFromString("blessButtonPressed:")

        NSApp.sendAction(action, to: report, from: NSButton())
        XCTAssertEqual(recorder.blessed.count, 0)

        // A button for a knot that's not on the line changes, but blesses nothing
        let button = IFSkeinBlessButton()
        button.tag = Int(add("wait", to: skein.rootItem, actual: "Time passes.\n>").uniqueId)
        NSApp.sendAction(action, to: report, from: button)
        XCTAssertFalse(button.blessState)
        XCTAssertEqual(recorder.blessed.count, 0)
    }

    /// The report doesn't keep its delegate, which keeps the report
    func testTheDelegateIsntKept() {
        let report = IFSkeinReportView()
        weak var weakRecorder: Recorder?
        autoreleasepool {
            let recorder = Recorder()
            report.delegate = recorder
            weakRecorder = recorder
            XCTAssertIdentical(report.delegate, recorder)
        }
        XCTAssertNil(weakRecorder)
        XCTAssertNil(report.delegate)
    }

    // MARK: - The font size

    /// The text is the report's size, times the app's font size multiplier
    func testTheFontSize() throws {
        let (look, _) = makeSkein()
        IFSkeinReportView.adjustAttributesToFontSize()
        let text = try text(try XCTUnwrap(entries(makeReport(selecting: look)).last))
        XCTAssertEqual((text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, fontSize)
        XCTAssertEqual((text.attribute(.font, at: 5, effectiveRange: nil) as? NSFont)?.pointSize, fontSize)
    }

    // MARK: - Drawing

    /// The report is drawn on yellow, with a dashed line between entries
    func testDrawing() throws {
        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        let details = details(report).map { CGFloat($0) }

        let bitmap = try XCTUnwrap(report.bitmapImageRepForCachingDisplay(in: report.bounds))
        report.cacheDisplay(in: report.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / report.bounds.width
        /// The colour at a point measured from the bottom of the report
        func colour(x: CGFloat, y: CGFloat) throws -> NSColor {
            let pixel = try XCTUnwrap(bitmap.colorAt(x: Int(x * scale), y: Int((report.bounds.height - y) * scale)))
            return try XCTUnwrap(pixel.usingColorSpace(.sRGB))
        }

        // The background, beside the bottom entry's text, is yellow
        let background = try colour(x: 1, y: details[2] / 2)
        XCTAssertGreaterThan(background.redComponent, 0.8)
        XCTAssertGreaterThan(background.greenComponent, 0.7)
        XCTAssertLessThan(background.blueComponent, 0.5)

        // A separator below each entry but the bottom one, dashed: 8 points drawn, then 6 not
        for top in [details[2], details[2] + details[1]] {
            let line = floor(top) - 0.5
            let dash = try colour(x: 2, y: line)
            XCTAssertLessThan(dash.redComponent, background.redComponent - 0.1)
            let gap = try colour(x: 10, y: line)
            XCTAssertEqual(gap.redComponent, background.redComponent, accuracy: 0.01)
        }
        // None at the top
        let top = try colour(x: 2, y: report.bounds.height - 0.5)
        XCTAssertEqual(top.redComponent, background.redComponent, accuracy: 0.01)
    }

    // MARK: - The mouse

    /// The report keeps the mouse's clicks and drags from the skein view behind it
    func testTheMouse() throws {
        let behind = MouseRecorder()
        let report = IFSkeinReportView()
        behind.addSubview(report)

        report.mouseDown(with: try mouseEvent(.leftMouseDown))
        report.mouseDragged(with: try mouseEvent(.leftMouseDragged))
        report.mouseUp(with: try mouseEvent(.leftMouseUp))
        XCTAssertEqual(behind.events, [])

        // As a plain view would pass them on
        let plain = NSView()
        behind.addSubview(plain)
        plain.mouseDown(with: try mouseEvent(.leftMouseDown))
        XCTAssertEqual(behind.events, ["down"])
    }

    /// Over the report, the cursor is an arrow
    func testTheCursor() throws {
        let report = IFSkeinReportView()
        NSCursor.pointingHand.set()

        report.cursorUpdate(with: try mouseEvent(.leftMouseDown))
        XCTAssertIdentical(NSCursor.current, NSCursor.arrow)
    }

    /// The report sets the cursor over its visible rectangle, while its window is key, with one tracking area,
    /// however often its tracking areas are updated
    func testTrackingTheMouse() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let (_, north) = makeSkein()
        let report = makeReport(selecting: north)
        window.contentView?.addSubview(report)

        report.updateTrackingAreas()
        report.updateTrackingAreas()
        let areas = report.trackingAreas.filter { ($0.owner as AnyObject?) === report }
        XCTAssertEqual(areas.count, 1)
        let area = try XCTUnwrap(areas.first)
        XCTAssertEqual(area.rect, report.visibleRect)
        XCTAssertEqual(area.options.subtracting(.assumeInside), [.cursorUpdate, .activeInKeyWindow])
    }
}
