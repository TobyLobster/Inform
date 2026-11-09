//
//  IFFindControllerTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests leave the user's own alone
private final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

/// A window controller that can find the next match and nothing else, recording what it's asked to find
private final class FindNextOnly: NSWindowController, IFFindDelegate {
    private(set) var found: [String] = []

    func findNextMatch(_ match: String, of type: IFFindType, completionHandler: ((Bool) -> Void)?) {
        found.append(match)
    }
}

/// The Find panel, finding in a text view in a window that the tests tell the panel is the main window. The panel's
/// window is loaded but never shown, and never closed, as closing it saves its frame in the user's defaults. Not
/// finding a match beeps, so some of these tests do.
final class IFFindControllerTests: XCTestCase {

    /// The windows the test has made, kept until it ends
    private var windows: [NSWindow] = []

    override func tearDown() {
        windows = []
        super.tearDown()
    }

    /// What can be shown below the controls
    private enum Below: Equatable {
        case regexpHelp
        case foundNothing
        case results
    }

    // MARK: - Helpers

    /// A controller keeping its histories in memory, starting with these histories, with its window loaded off the
    /// screen
    private func makeController(findHistory: [String]? = nil,
                                replaceHistory: [String]? = nil) throws -> (controller: IFFindController,
                                                                            defaults: MemoryDefaults,
                                                                            window: NSWindow) {
        let defaults = MemoryDefaults()
        if let findHistory {
            defaults.set(findHistory, forKey: "IFFindHistory")
        }
        if let replaceHistory {
            defaults.set(replaceHistory, forKey: "IFReplaceHistory")
        }
        let controller = IFFindController(defaults: defaults)
        let window = try XCTUnwrap(controller.window)
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        return (controller, defaults, window)
    }

    /// A window off the screen, never shown, with a text view of this text as its first responder, with nothing
    /// selected at its start
    private func makeTextWindow(_ text: String) -> (window: NSWindow, textView: NSTextView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: true)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        window.contentView = textView
        window.makeFirstResponder(textView)
        windows.append(window)
        return (window, textView)
    }

    /// Tells the controllers that the window has become the main window
    private func makeMain(_ window: NSWindow) {
        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: window)
    }

    /// A text view of this text, in the main window as far as the controller knows
    private func finder(_ text: String) -> NSTextView {
        let (window, textView) = makeTextWindow(text)
        makeMain(window)
        return textView
    }

    /// Every view of this type in the view, the view included
    private func views<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        var found: [T] = []
        if let view = view as? T {
            found.append(view)
        }
        for subview in view.subviews {
            found += views(type, in: subview)
        }
        return found
    }

    private func views<T: NSView>(_ type: T.Type, in window: NSWindow) -> [T] {
        return views(type, in: window.contentView!)
    }

    /// The find box, which is followed by the replace box
    private func findBox(_ window: NSWindow) -> NSComboBox {
        return views(NSComboBox.self, in: window).first { $0.nextKeyView is NSComboBox }!
    }

    private func replaceBox(_ window: NSWindow) -> NSComboBox {
        return views(NSComboBox.self, in: window).first { !($0.nextKeyView is NSComboBox) }!
    }

    private func button(_ title: String, _ window: NSWindow) -> NSButton {
        let found = views(NSButton.self, in: window).filter { $0.title == title && !($0 is NSPopUpButton) }
        XCTAssertEqual(found.count, 1, title)
        return found[0]
    }

    private let buttonTitles = ["Next", "Previous", "Find All", "Replace", "Replace All", "Replace & Find"]

    /// The buttons that are enabled, of Next, Previous, Find All, Replace, Replace All and Replace & Find
    private func enabledButtons(_ window: NSWindow) -> [String] {
        return buttonTitles.filter { button($0, window).isEnabled }
    }

    private func searchType(_ window: NSWindow) -> NSPopUpButton {
        return views(NSPopUpButton.self, in: window)[0]
    }

    /// The types of search that can be chosen
    private func enabledTypes(_ window: NSWindow) -> [String] {
        return searchType(window).itemArray.filter(\.isEnabled).map(\.title)
    }

    private func table(_ window: NSWindow) throws -> NSTableView {
        return try XCTUnwrap(views(NSTableView.self, in: window).first)
    }

    private func countText(_ window: NSWindow) -> String? {
        return views(NSTextField.self, in: window).first { $0.stringValue.hasPrefix("Found") }?.stringValue
    }

    /// What's shown below the controls
    private func below(_ window: NSWindow) -> [Below] {
        var shown: [Below] = []
        if views(NSTextView.self, in: window).contains(where: { !$0.isEditable && !$0.isSelectable }) {
            shown.append(.regexpHelp)
        }
        if views(NSTextField.self, in: window).contains(where: { $0.stringValue == "No matches were found" }) {
            shown.append(.foundNothing)
        }
        if !views(NSTableView.self, in: window).isEmpty {
            shown.append(.results)
        }
        return shown
    }

    /// Types the phrase into the find box, as the user would
    private func type(_ phrase: String, with controller: IFFindController) throws {
        let box = findBox(try XCTUnwrap(controller.window))
        box.stringValue = phrase
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: box))
    }

    private func rows(_ table: NSTableView) -> Int {
        return table.dataSource?.numberOfRows?(in: table) ?? -1
    }

    private func context(_ row: Int, _ table: NSTableView) -> NSAttributedString? {
        return table.dataSource?.tableView?(table, objectValueFor: table.tableColumns[0], row: row) as? NSAttributedString
    }

    private func items(_ box: NSComboBox) -> [String] {
        let count = box.dataSource?.numberOfItems?(in: box) ?? -1
        return (0..<max(count, 0)).map { box.dataSource?.comboBox?(box, objectValueForItemAt: $0) as? String ?? "?" }
    }

    private func selected(_ textView: NSTextView) -> String {
        return (textView.string as NSString).substring(with: textView.selectedRange())
    }

    // MARK: - The controls

    /// With nothing to search, nothing can be typed or clicked, but every type of search can be chosen
    func testWithNothingToSearchTheControlsAreDisabled() throws {
        let (_, _, window) = try makeController()
        _ = finder("A beaker.")
        let plain = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        plain.isReleasedWhenClosed = false
        windows.append(plain)
        makeMain(plain)
        XCTAssertFalse(findBox(window).isEnabled)
        XCTAssertFalse(replaceBox(window).isEnabled)
        XCTAssertFalse(button("Ignore Case", window).isEnabled)
        XCTAssertFalse(searchType(window).isEnabled)
        XCTAssertEqual(enabledButtons(window), [])
        XCTAssertEqual(enabledTypes(window), ["Contains", "Starts with", "Full word", "Regular expression"])
    }

    /// With a text view to search, everything can be typed and chosen, and the buttons are enabled once there's a
    /// phrase
    func testWithATextViewEverythingIsEnabledOnceThereIsAPhrase() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        XCTAssertTrue(findBox(window).isEnabled)
        XCTAssertTrue(replaceBox(window).isEnabled)
        XCTAssertTrue(button("Ignore Case", window).isEnabled)
        XCTAssertTrue(searchType(window).isEnabled)
        XCTAssertEqual(enabledTypes(window), ["Contains", "Starts with", "Full word", "Regular expression"])
        XCTAssertEqual(enabledButtons(window), [])

        try type("beaker", with: controller)
        XCTAssertEqual(enabledButtons(window), buttonTitles)
        try type("", with: controller)
        XCTAssertEqual(enabledButtons(window), [])
    }

    /// With something that can only find the next match, only Next and Previous are enabled, and regular expressions
    /// can't be chosen
    func testWithSomethingThatOnlyFindsTheNextMatch() throws {
        let (controller, _, window) = try makeController()
        let (textWindow, _) = makeTextWindow("A beaker.")
        let finder = FindNextOnly(window: textWindow)
        makeMain(textWindow)
        try type("beaker", with: controller)
        XCTAssertTrue(findBox(window).isEnabled)
        XCTAssertFalse(replaceBox(window).isEnabled)
        XCTAssertEqual(enabledButtons(window), ["Next", "Previous"])
        XCTAssertEqual(enabledTypes(window), ["Contains", "Starts with", "Full word"])
        withExtendedLifetime(finder) {}
    }

    /// The window's controller is asked to find before its first responder
    func testTheWindowsControllerFindsBeforeItsFirstResponder() throws {
        let (controller, _, _) = try makeController()
        let (textWindow, textView) = makeTextWindow("A beaker.")
        let finder = FindNextOnly(window: textWindow)
        makeMain(textWindow)
        try type("beaker", with: controller)
        controller.findNext(nil)
        XCTAssertEqual(finder.found, ["beaker"])
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testAnotherControlsTextChangingLeavesTheButtonsAlone() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        findBox(window).stringValue = "beaker"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification,
                                                     object: replaceBox(window)))
        XCTAssertEqual(enabledButtons(window), [])
    }

    /// Choosing a regular expression search shows help on them below the controls, making the window taller while
    /// keeping its top where it was, and choosing another type of search hides it again
    func testChoosingARegularExpressionShowsHelpOnThem() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        let frame = window.frame
        searchType(window).selectItem(withTitle: "Regular expression")
        controller.findTypeChanged(nil)
        XCTAssertEqual(below(window), [.regexpHelp])
        XCTAssertGreaterThan(window.frame.height, frame.height)
        XCTAssertEqual(window.frame.maxY, frame.maxY)

        searchType(window).selectItem(withTitle: "Full word")
        controller.findTypeChanged(nil)
        XCTAssertEqual(below(window), [])
        XCTAssertEqual(window.frame, frame)
    }

    // MARK: - Finding

    /// Next selects the next match, from the selection, going round to the start
    func testNextSelectsTheNextMatch() throws {
        let (controller, _, _) = try makeController()
        let textView = finder("A beaker. A flask. A beaker.")
        try type("beaker", with: controller)
        controller.findNext(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 6))
        controller.findNext(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 21, length: 6))
        controller.findNext(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 6))
    }

    func testPreviousSelectsThePreviousMatch() throws {
        let (controller, _, _) = try makeController()
        let textView = finder("A beaker. A flask. A beaker.")
        textView.setSelectedRange(NSRange(location: 20, length: 0))
        try type("beaker", with: controller)
        controller.findPrevious(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 6))
    }

    /// With no phrase, Next, Previous, and Replace & Find do nothing
    func testWithNoPhraseNothingIsFound() throws {
        let (controller, defaults, window) = try makeController()
        let textView = finder("A beaker.")
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        replaceBox(window).stringValue = "flask"
        controller.findNext(nil)
        controller.findPrevious(nil)
        controller.replaceAndFind(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 4, length: 0))
        XCTAssertEqual(textView.string, "A beaker.")
        XCTAssertNil(defaults.object(forKey: "IFFindHistory"))
        XCTAssertNil(defaults.object(forKey: "IFReplaceHistory"))
    }

    /// The search is as the controls say
    func testFindsAsTheControlsSay() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("The BEAKER, beakers and a beaker.")
        func next(_ phrase: String, _ type: String, ignoringCase: Bool) throws -> NSRange {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            searchType(window).selectItem(withTitle: type)
            button("Ignore Case", window).state = ignoringCase ? .on : .off
            try self.type(phrase, with: controller)
            controller.findNext(nil)
            return textView.selectedRange()
        }
        XCTAssertEqual(try next("beaker", "Contains", ignoringCase: true), NSRange(location: 4, length: 6))
        XCTAssertEqual(try next("beaker", "Contains", ignoringCase: false), NSRange(location: 12, length: 6))
        XCTAssertEqual(try next("beaker", "Full word", ignoringCase: false), NSRange(location: 26, length: 6))
        XCTAssertEqual(try next("eaker", "Starts with", ignoringCase: true), NSRange(location: 0, length: 0))
        XCTAssertEqual(try next("b.akers", "Regular expression", ignoringCase: true), NSRange(location: 12, length: 7))
    }

    /// Return in the find box finds the next match, and puts the window away
    func testReturnInTheFindBoxFindsTheNextMatch() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker.")
        try type("beaker", with: controller)
        controller.comboBoxEnterKeyPress(findBox(window))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 6))
        XCTAssertFalse(window.isVisible)
    }

    func testReturnInTheReplaceBoxFindsTheNextMatch() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker.")
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "flask"
        controller.comboBoxEnterKeyPress(replaceBox(window))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 6))
        XCTAssertEqual(textView.string, "A beaker.")
    }

    /// Use Selection for Find puts the selection in the find box and finds its next match, as Contains
    func testUseSelectionForFind() throws {
        let (controller, defaults, window) = try makeController()
        let textView = finder("A flask. A beaker. A flask.")
        textView.setSelectedRange(NSRange(location: 2, length: 5))
        searchType(window).selectItem(withTitle: "Full word")
        controller.useSelectionForFind(nil)
        XCTAssertEqual(findBox(window).stringValue, "flask")
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Contains")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 21, length: 5))
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["flask"])
    }

    /// With nothing selected, Use Selection for Find beeps and leaves the find box alone
    func testUseSelectionForFindWithNothingSelected() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A flask.")
        try type("beaker", with: controller)
        controller.useSelectionForFind(nil)
        XCTAssertEqual(findBox(window).stringValue, "beaker")
    }

    // MARK: - Replacing

    /// Replace replaces the selection with what's in the replace box
    func testReplaceReplacesTheSelection() throws {
        let (controller, defaults, window) = try makeController()
        let textView = finder("A beaker. A beaker.")
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "flask"
        controller.findNext(nil)
        controller.replace(nil)
        XCTAssertEqual(textView.string, "A flask. A beaker.")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 5))
        XCTAssertEqual(defaults.object(forKey: "IFReplaceHistory") as? [String], ["flask"])
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker"])
    }

    /// Replace & Find replaces the selection and then finds the next match
    func testReplaceAndFindReplacesThenFindsTheNextMatch() throws {
        let (controller, defaults, window) = try makeController()
        let textView = finder("A beaker. A beaker.")
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "flask"
        controller.findNext(nil)
        controller.replaceAndFind(nil)
        XCTAssertEqual(textView.string, "A flask. A beaker.")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 11, length: 6))
        XCTAssertEqual(defaults.object(forKey: "IFReplaceHistory") as? [String], ["flask"])
    }

    /// With a regular expression, Replace & Find puts what its groups matched for \1 and so on
    func testReplaceAndFindExpandsARegularExpressionsGroups() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker. A flask.")
        searchType(window).selectItem(withTitle: "Regular expression")
        try type("A (\\w+)", with: controller)
        replaceBox(window).stringValue = "The \\1"
        controller.findNext(nil)
        controller.replaceAndFind(nil)
        XCTAssertEqual(textView.string, "The beaker. A flask.")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 12, length: 7))
    }

    /// Replace All replaces every match, and lists them
    func testReplaceAllReplacesEveryMatch() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker. A flask. A beaker.")
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "bottle"
        controller.replaceAll(nil)
        XCTAssertEqual(textView.string, "A bottle. A flask. A bottle.")
        XCTAssertEqual(below(window), [.results])
        XCTAssertEqual(countText(window), "Found 2 results:")
        let results = try table(window)
        XCTAssertEqual(rows(results), 2)
        XCTAssertEqual(context(0, results)?.string, "A bottle. A flask. A beaker.")
        XCTAssertEqual(context(1, results)?.string, "A beaker. A flask. A bottle.")
    }

    /// Replace All remembers the phrase in the find history, and the replacement in the replace history
    func testReplaceAllRemembersWhatWasTypedInEachBox() throws {
        let (controller, defaults, window) = try makeController()
        _ = finder("A beaker. A flask. A beaker.")
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "bottle"
        controller.replaceAll(nil)
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker"])
        XCTAssertEqual(defaults.object(forKey: "IFReplaceHistory") as? [String], ["bottle"])
    }

    /// With a regular expression, Replace All puts what each match's groups matched for \1 and so on
    func testReplaceAllExpandsARegularExpressionsGroups() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker. A flask.")
        searchType(window).selectItem(withTitle: "Regular expression")
        try type("A (\\w+)", with: controller)
        replaceBox(window).stringValue = "The \\1"
        controller.replaceAll(nil)
        XCTAssertEqual(textView.string, "The beaker. The flask.")
    }

    /// What can't be replaced is listed in red
    func testReplaceAllListsWhatItCouldNotReplaceInRed() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker.")
        textView.isEditable = false
        try type("beaker", with: controller)
        replaceBox(window).stringValue = "flask"
        controller.replaceAll(nil)
        XCTAssertEqual(textView.string, "A beaker.")
        let colour = context(0, try table(window))?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(colour, NSColor.systemRed)
    }

    // MARK: - Find All

    /// Find All lists every match below the controls, with their count
    func testFindAllListsEveryMatch() throws {
        let (controller, defaults, window) = try makeController()
        let textView = finder("A beaker.\nA flask.\nThe beaker is fragile.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        XCTAssertEqual(below(window), [.results])
        XCTAssertEqual(countText(window), "Found 2 results:")
        let results = try table(window)
        XCTAssertEqual(rows(results), 2)
        XCTAssertEqual(context(0, results)?.string, "A beaker.")
        XCTAssertEqual(context(1, results)?.string, "The beaker is fragile.")
        XCTAssertNil(context(2, results))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker"])
    }

    func testFindAllCountsASingleMatch() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        XCTAssertEqual(countText(window), "Found 1 result:")
    }

    func testFindAllSaysWhenNothingIsFound() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        try type("flask", with: controller)
        controller.findAll(nil)
        XCTAssertEqual(below(window), [.foundNothing])
    }

    /// Selecting a match in the list selects it in the text
    func testSelectingAMatchInTheListSelectsIt() throws {
        let (controller, _, window) = try makeController()
        let textView = finder("A beaker.\nA flask.\nThe beaker is fragile.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        try table(window).selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 23, length: 6))
    }

    func testTheListDoesntShowExpansionToolTips() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        let results = try table(window)
        XCTAssertEqual(results.delegate?.tableView?(results, shouldShowCellExpansionFor: results.tableColumns[0], row: 0),
                       false)
    }

    /// The window grows by a row for each match, up to twenty, keeping its top where it was
    func testTheWindowGrowsByARowForEachMatchUpToTwenty() throws {
        let (controller, _, window) = try makeController()
        let words = ["alpha": 1, "beta": 2, "gamma": 20, "delta": 21]
        _ = finder(words.map { String(repeating: "\($0.key)\n", count: $0.value) }.joined())
        let top = window.frame.maxY
        var heights: [String: CGFloat] = [:]
        for word in words.keys {
            try type(word, with: controller)
            controller.findAll(nil)
            XCTAssertEqual(rows(try table(window)), words[word])
            XCTAssertEqual(window.frame.maxY, top)
            heights[word] = window.frame.height
        }
        let results = try table(window)
        let row = results.rowHeight + results.intercellSpacing.height
        XCTAssertEqual(heights["beta"]! - heights["alpha"]!, row)
        XCTAssertEqual(heights["gamma"]! - heights["alpha"]!, 19 * row)
        XCTAssertEqual(heights["delta"], heights["gamma"])
    }

    /// Finding another phrase puts the list away, and finding the same phrase leaves it
    func testFindingAnotherPhrasePutsTheListAway() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker. A flask.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        controller.findNext(nil)
        XCTAssertEqual(below(window), [.results])
        try type("flask", with: controller)
        controller.findNext(nil)
        XCTAssertEqual(below(window), [])
    }

    /// Another window becoming the main window puts the list away, but not the regular expression help
    func testAnotherMainWindowPutsTheListAway() throws {
        let (controller, _, window) = try makeController()
        _ = finder("A beaker.")
        try type("beaker", with: controller)
        controller.findAll(nil)
        _ = finder("A flask.")
        XCTAssertEqual(below(window), [])

        searchType(window).selectItem(withTitle: "Regular expression")
        controller.findTypeChanged(nil)
        _ = finder("A bottle.")
        XCTAssertEqual(below(window), [.regexpHelp])
    }

    // MARK: - The histories

    /// The find and replace boxes offer their histories, which start as the defaults have them
    func testTheBoxesOfferTheirHistories() throws {
        let (_, _, window) = try makeController(findHistory: ["beaker", "flask"], replaceHistory: ["bottle"])
        XCTAssertEqual(items(findBox(window)), ["beaker", "flask"])
        XCTAssertEqual(items(replaceBox(window)), ["bottle"])
    }

    /// A phrase found again moves to the front of the history, which keeps the last thirty
    func testTheFindHistoryKeepsTheLastThirtyPhrases() throws {
        let history = (1...30).map { "phrase \($0)" }
        let (controller, defaults, window) = try makeController(findHistory: history)
        _ = finder("A beaker.")
        try type("phrase 2", with: controller)
        controller.findNext(nil)
        try type("beaker", with: controller)
        controller.findNext(nil)
        let expected = ["beaker", "phrase 2", "phrase 1"] + (3...29).map { "phrase \($0)" }
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], expected)
        XCTAssertEqual(items(findBox(window)), expected)
    }

    func testTheReplaceHistoryKeepsTheLastThirtyPhrases() throws {
        let history = (1...30).map { "phrase \($0)" }
        let (controller, defaults, window) = try makeController(replaceHistory: history)
        _ = finder("A beaker. A beaker.")
        try type("beaker", with: controller)
        controller.findNext(nil)
        replaceBox(window).stringValue = "phrase 2"
        controller.replace(nil)
        controller.findNext(nil)
        replaceBox(window).stringValue = "flask"
        controller.replace(nil)
        let expected = ["flask", "phrase 2", "phrase 1"] + (3...29).map { "phrase \($0)" }
        XCTAssertEqual(defaults.object(forKey: "IFReplaceHistory") as? [String], expected)
        XCTAssertEqual(items(replaceBox(window)), expected)
    }

    /// A box is offered nothing past its history, and another box nothing at all
    func testNothingIsOfferedPastTheHistory() throws {
        let (_, _, window) = try makeController(findHistory: ["beaker"])
        let box = findBox(window)
        XCTAssertNil(box.dataSource?.comboBox?(box, objectValueForItemAt: 1))
        XCTAssertNil(box.dataSource?.comboBox?(box, objectValueForItemAt: -1))
        let other = NSComboBox()
        XCTAssertEqual(box.dataSource?.numberOfItems?(in: other), 0)
        XCTAssertNil(box.dataSource?.comboBox?(other, objectValueForItemAt: 0))
    }
}
