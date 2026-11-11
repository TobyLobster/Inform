//
//  IFFindInFilesControllerTests.swift
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

/// A project controller that records the results it's asked to show
private final class ProjectControllerStandIn: IFProjectController {
    struct Shown: Equatable {
        let location: Int
        let phrase: String
        let file: String
        let type: IFFindLocation
        let anchorTag: String?
    }

    private(set) var shown: [Shown] = []

    /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }

    override func searchShowSelectedItem(atLocation location: Int,
                                         phrase: String,
                                         inFile filename: String,
                                         type: IFFindLocation,
                                         anchorTag: String?) {
        shown.append(Shown(location: location, phrase: phrase, file: filename, type: type, anchorTag: anchorTag))
    }
}

/// The controller's window is loaded but never shown, and never closed, as closing it saves its frame in the user's
/// defaults.
@MainActor
final class IFFindInFilesControllerTests: XCTestCase {

    /// What can be shown below the controls
    private enum Below: Equatable {
        case regexpHelp
        case foundNothing
        case results
    }

    // MARK: - Helpers

    /// A controller keeping its find history in memory, starting with this history, with its window loaded off the
    /// screen
    private func makeController(history: [String]? = nil) throws -> (controller: IFFindInFilesController,
                                                                      defaults: MemoryDefaults,
                                                                      window: NSWindow) {
        let defaults = MemoryDefaults()
        if let history {
            defaults.set(history, forKey: "IFFindHistory")
        }
        let controller = IFFindInFilesController(defaults: defaults)
        let window = try XCTUnwrap(controller.window)
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        return (controller, defaults, window)
    }

    /// A project in a new folder, with these files in its Source folder, opened as the app does. The folder is
    /// removed, and the project closed, when the test ends.
    private func openProject(source: [String: String]) throws -> IFProject {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Lab.inform")
        let sourceFolder = url.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        for (filename, text) in source {
            try Data(text.utf8).write(to: sourceFolder.appendingPathComponent(filename))
        }
        let project = try IFProject(contentsOf: url, ofType: "org.inform-fiction.project")
        addTeardownBlock { project.close() }
        return project
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

    private func phraseBox(_ window: NSWindow) -> NSComboBox {
        return views(NSComboBox.self, in: window)[0]
    }

    private func button(_ title: String, _ window: NSWindow) -> NSButton {
        let found = views(NSButton.self, in: window).filter { $0.title == title && !($0 is NSPopUpButton) }
        XCTAssertEqual(found.count, 1, title)
        return found[0]
    }

    private func searchType(_ window: NSWindow) -> NSPopUpButton {
        return views(NSPopUpButton.self, in: window)[0]
    }

    private func progress(_ window: NSWindow) -> NSProgressIndicator {
        return views(NSProgressIndicator.self, in: window)[0]
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

    /// Waits for the search to finish, which is when the progress indicator is hidden
    private func waitForTheSearch(_ window: NSWindow, file: StaticString = #filePath, line: UInt = #line) {
        let indicator = progress(window)
        let deadline = Date(timeIntervalSinceNow: 60)
        while !indicator.isHidden && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertTrue(indicator.isHidden, "The search finishes", file: file, line: line)
    }

    /// Types the phrase into the find box, clicks Find All, and waits for the search to finish
    private func findAll(_ phrase: String,
                         with controller: IFFindInFilesController,
                         file: StaticString = #filePath,
                         line: UInt = #line) throws {
        let window = try XCTUnwrap(controller.window)
        phraseBox(window).stringValue = phrase
        controller.findAll(nil)
        waitForTheSearch(window, file: file, line: line)
    }

    private func rows(_ table: NSTableView) -> Int {
        return table.dataSource?.numberOfRows?(in: table) ?? -1
    }

    /// The column with this identifier, or the document column for nil, as it has none
    private func column(_ identifier: String?, _ table: NSTableView) -> NSTableColumn {
        return table.tableColumns.first { column in
            let id = column.identifier.rawValue
            return identifier == nil ? (id != "context" && id != "location") : (id == identifier)
        }!
    }

    private func value(_ identifier: String?, _ row: Int, _ table: NSTableView) -> Any? {
        return table.dataSource?.tableView?(table, objectValueFor: column(identifier, table), row: row)
    }

    private func historyItems(_ window: NSWindow) -> [String] {
        let box = phraseBox(window)
        let count = box.dataSource?.numberOfItems?(in: box) ?? -1
        return (0..<max(count, 0)).map { box.dataSource?.comboBox?(box, objectValueForItemAt: $0) as? String ?? "?" }
    }

    private func type(_ type: IFFindType, ignoringCase: Bool) -> IFFindType {
        return IFFindType(rawValue: type.rawValue | (ignoringCase ? IFFindType.caseInsensitive.rawValue : 0))!
    }

    // MARK: - The controls

    /// The window starts by searching the source for what contains the phrase, ignoring case, with nothing shown
    /// below the controls, and with Find All disabled as there's no phrase
    func testTheControlsStartReadyToSearchTheSource() throws {
        let (_, _, window) = try makeController()
        XCTAssertEqual(phraseBox(window).stringValue, "")
        XCTAssertFalse(button("Find All", window).isEnabled)
        XCTAssertEqual(button("Source", window).state, .on)
        XCTAssertEqual(button("Installed Extensions", window).state, .off)
        XCTAssertEqual(button("Main Text", window).state, .off)
        XCTAssertEqual(button("Source Examples", window).state, .off)
        XCTAssertEqual(button("Phrase Definitions", window).state, .off)
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Contains")
        XCTAssertEqual(button("Ignore Case", window).state, .on)
        XCTAssertTrue(progress(window).isHidden)
        XCTAssertEqual(below(window), [])
    }

    /// Find All is enabled when the phrase changes to something, and disabled when it changes to nothing
    func testFindAllIsEnabledOnlyWithAPhrase() throws {
        let (controller, _, window) = try makeController()
        let box = phraseBox(window)
        box.stringValue = "beaker"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: box))
        XCTAssertTrue(button("Find All", window).isEnabled)
        box.stringValue = ""
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: box))
        XCTAssertFalse(button("Find All", window).isEnabled)
    }

    func testAnotherControlsTextChangingLeavesFindAllAlone() throws {
        let (controller, _, window) = try makeController()
        phraseBox(window).stringValue = "beaker"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: NSTextField()))
        XCTAssertFalse(button("Find All", window).isEnabled)
    }

    /// Choosing a regular expression search shows help on them below the controls, making the window taller while
    /// keeping its top where it was, and choosing another type of search hides it again
    func testChoosingARegularExpressionShowsHelpOnThem() throws {
        let (controller, _, window) = try makeController()
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

    /// Choosing another type of search leaves what was found shown
    func testChoosingAnotherTypeOfSearchLeavesTheResultsShown() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        searchType(window).selectItem(withTitle: "Starts with")
        controller.findTypeChanged(nil)
        XCTAssertEqual(below(window), [.results])
    }

    // MARK: - Searching

    /// Nothing found says so below the controls
    func testSaysWhenNothingIsFound() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("flask", with: controller)
        XCTAssertEqual(below(window), [.foundNothing])
        XCTAssertTrue(progress(window).isHidden)
    }

    /// What's found is listed below the controls, with its count
    func testListsWhatIsFound() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "The Lab is a room.\nA beaker is in the Lab.",
                                                       "Part 9.i7": "The beaker is fragile."]))
        try findAll("beaker", with: controller)
        XCTAssertEqual(below(window), [.results])
        XCTAssertEqual(countText(window), "Found 2 results:")
        let results = try table(window)
        XCTAssertEqual(rows(results), 2)
        XCTAssertEqual((value("context", 0, results) as? NSAttributedString)?.string, "The beaker is fragile.")
        XCTAssertEqual(value(nil, 0, results) as? String, "Part 9")
        XCTAssertEqual(value("location", 0, results) as? String, "Source")
        XCTAssertEqual((value("context", 1, results) as? NSAttributedString)?.string, "A beaker is in the Lab.")
        XCTAssertEqual(value(nil, 1, results) as? String, "(Source Text)", "The story is named as the source text")
        XCTAssertEqual(value("location", 1, results) as? String, "Source")
    }

    func testCountsASingleResult() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        XCTAssertEqual(countText(window), "Found 1 result:")
        XCTAssertEqual(rows(try table(window)), 1)
    }

    /// A new search replaces what the last one found
    func testANewSearchReplacesTheLastOnesResults() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker. A flask."]))
        try findAll("beaker", with: controller)
        try findAll("bottle", with: controller)
        XCTAssertEqual(below(window), [.foundNothing])
        try findAll("flask", with: controller)
        XCTAssertEqual(below(window), [.results])
        XCTAssertEqual((value("context", 0, try table(window)) as? NSAttributedString)?.string, "A beaker. A flask.")
    }

    /// The window grows by a row for each result, up to twenty, keeping its top where it was
    func testTheWindowGrowsByARowForEachResultUpToTwenty() throws {
        let (controller, _, window) = try makeController()
        let words = ["alpha": 1, "beta": 2, "gamma": 20, "delta": 21]
        let text = words.map { String(repeating: "\($0.key) ", count: $0.value) }.joined(separator: "\n")
        controller.setProject(try openProject(source: ["story.ni": text]))
        let top = window.frame.maxY
        var heights: [String: CGFloat] = [:]
        for word in words.keys {
            try findAll(word, with: controller)
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

    /// The search finds what the controls ask for
    func testSearchesAsTheControlsSay() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "Beaker and beakers."]))
        func found(_ phrase: String, _ type: String, ignoringCase: Bool) throws -> Int {
            searchType(window).selectItem(withTitle: type)
            button("Ignore Case", window).state = ignoringCase ? .on : .off
            try findAll(phrase, with: controller)
            return below(window) == [.foundNothing] ? 0 : rows(try table(window))
        }
        XCTAssertEqual(try found("beaker", "Contains", ignoringCase: true), 2)
        XCTAssertEqual(try found("beaker", "Contains", ignoringCase: false), 1)
        XCTAssertEqual(try found("beaker", "Full word", ignoringCase: true), 1)
        XCTAssertEqual(try found("eaker", "Starts with", ignoringCase: true), 0)
        XCTAssertEqual(try found("beak", "Starts with", ignoringCase: true), 2)
        XCTAssertEqual(try found("b.aker", "Regular expression", ignoringCase: true), 2)
    }

    /// The search looks where the check boxes say
    func testSearchesWhereTheCheckBoxesSay() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        button("Source", window).state = .off
        try findAll("beaker", with: controller)
        XCTAssertEqual(below(window), [.foundNothing])
        button("Source", window).state = .on
        try findAll("beaker", with: controller)
        XCTAssertEqual(below(window), [.results])
    }

    /// Return in the find box searches
    func testReturnInTheFindBoxSearches() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        phraseBox(window).stringValue = "beaker"
        controller.comboBoxEnterKeyPress(phraseBox(window))
        waitForTheSearch(window)
        XCTAssertEqual(below(window), [.results])
    }

    /// Return in an empty find box does nothing, as Find All is disabled
    func testReturnInAnEmptyFindBoxDoesNothing() throws {
        let (controller, defaults, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        controller.comboBoxEnterKeyPress(phraseBox(window))
        XCTAssertTrue(progress(window).isHidden)
        XCTAssertNil(defaults.object(forKey: "IFFindHistory"))
        waitForTheSearch(window)
        XCTAssertEqual(below(window), [])
    }

    func testReturnInAnotherControlDoesNothing() throws {
        let (controller, defaults, window) = try makeController()
        phraseBox(window).stringValue = "beaker"
        controller.comboBoxEnterKeyPress(NSComboBox())
        XCTAssertTrue(progress(window).isHidden)
        XCTAssertNil(defaults.object(forKey: "IFFindHistory"))
    }

    // MARK: - Starting a search from elsewhere

    /// The app's searches set the controls, and search
    func testStartingASearchSetsTheControlsAndSearches() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        controller.startFindInFilesSearch(withPhrase: "beaker",
                                          withLocationType: [.source, .documentationSource],
                                          with: .completeWord)
        XCTAssertEqual(phraseBox(window).stringValue, "beaker")
        XCTAssertTrue(button("Find All", window).isEnabled)
        XCTAssertEqual(button("Source", window).state, .on)
        XCTAssertEqual(button("Installed Extensions", window).state, .off)
        XCTAssertEqual(button("Main Text", window).state, .off)
        XCTAssertEqual(button("Source Examples", window).state, .on)
        XCTAssertEqual(button("Phrase Definitions", window).state, .off)
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Full word")
        XCTAssertEqual(button("Ignore Case", window).state, .off)
        waitForTheSearch(window)
        XCTAssertEqual(below(window), [.results])
    }

    /// ...as the app's own searches do: Search Documentation and Search Project
    func testStartingASearchThatIgnoresCase() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        controller.startFindInFilesSearch(withPhrase: "BEAKER",
                                          withLocationType: [.extensions, .documentationBasic, .documentationDefinitions],
                                          with: type(.contains, ignoringCase: true))
        XCTAssertEqual(button("Source", window).state, .off)
        XCTAssertEqual(button("Installed Extensions", window).state, .on)
        XCTAssertEqual(button("Main Text", window).state, .on)
        XCTAssertEqual(button("Source Examples", window).state, .off)
        XCTAssertEqual(button("Phrase Definitions", window).state, .on)
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Contains")
        XCTAssertEqual(button("Ignore Case", window).state, .on)
        waitForTheSearch(window)
    }

    func testStartingARegularExpressionSearch() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        searchType(window).selectItem(withTitle: "Full word")
        controller.startFindInFilesSearch(withPhrase: "b.aker", withLocationType: .source, with: .regexp)
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Regular expression")
        waitForTheSearch(window)
        XCTAssertEqual(below(window), [.results])
    }

    /// The type of search is chosen whether or not case is ignored
    func testStartingASearchOfAnotherTypeThatIgnoresCase() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        controller.startFindInFilesSearch(withPhrase: "BEAK",
                                          withLocationType: .source,
                                          with: type(.beginsWith, ignoringCase: true))
        XCTAssertEqual(searchType(window).titleOfSelectedItem, "Starts with")
        XCTAssertEqual(button("Ignore Case", window).state, .on)
        waitForTheSearch(window)
        XCTAssertEqual(below(window), [.results])
    }

    // MARK: - The results

    /// Clicking a result in the source shows the text that matched in the project
    func testClickingAResultShowsIt() throws {
        let (controller, _, window) = try makeController()
        let projectController = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(projectController)
        controller.setController(projectController)
        controller.setProject(try openProject(source: ["story.ni": "The Lab is a room.\nA beaker is in the Lab."]))
        try findAll("BEAKER", with: controller)
        controller.tableView(try table(window), didClickRow: 0)
        XCTAssertEqual(projectController.shown, [.init(location: 21,
                                                       phrase: "beaker",
                                                       file: "story.ni",
                                                       type: .source,
                                                       anchorTag: "")])
    }

    /// Clicking a result in the documentation shows it at the anchor of the code, definition or example it's in
    func testClickingAResultInTheDocumentationGivesItsAnchor() throws {
        let (controller, _, window) = try makeController()
        let projectController = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(projectController)
        controller.setController(projectController)
        controller.setProject(try openProject(source: [:]))
        func anchors(_ phrase: String, _ location: IFFindLocation) throws -> [String?] {
            controller.startFindInFilesSearch(withPhrase: phrase, withLocationType: location, with: .contains)
            waitForTheSearch(window)
            let results = try table(window)
            let before = projectController.shown.count
            for row in 0..<rows(results) {
                controller.tableView(results, didClickRow: row)
            }
            return projectController.shown.dropFirst(before).map { $0.anchorTag }
        }
        XCTAssertEqual(try anchors("Bodleian", .documentationSource), ["c1869", "c1869"])
        XCTAssertEqual(try anchors("arccosine", .documentationDefinitions).first, "defn210")
        let examples = try anchors("SYBIL", .documentationBasic)
        XCTAssertEqual(examples.first, "e350")
        XCTAssertEqual(Set(examples.dropFirst()), ["", "e350"])
    }

    /// The documentation's results are named by the book they're in, and the recipe book's are shown in yellow
    func testNamesTheBookOfEachResult() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: [:]))
        controller.startFindInFilesSearch(withPhrase: "SYBIL", withLocationType: .documentationBasic, with: .contains)
        waitForTheSearch(window)
        let results = try table(window)
        XCTAssertEqual((0..<rows(results)).map { value("location", $0, results) as? String },
                       ["Writing with Inform", "The Inform Recipe Book", "The Inform Recipe Book"])

        let backgrounds: [NSColor?] = (0..<rows(results)).map { row in
            let cell = NSTextFieldCell()
            cell.drawsBackground = true
            results.delegate?.tableView?(results, willDisplayCell: cell, for: column("context", results), row: row)
            return cell.drawsBackground ? cell.backgroundColor : nil
        }
        XCTAssertEqual(backgrounds, [nil,
                                     NSColor(calibratedRed: 1, green: 1, blue: 210 / 255, alpha: 1),
                                     NSColor(calibratedRed: 1, green: 1, blue: 224 / 255, alpha: 1)])
    }

    func testResultsDontShowExpansionToolTips() throws {
        let (controller, _, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        let results = try table(window)
        XCTAssertEqual(results.delegate?.tableView?(results,
                                                    shouldShowCellExpansionFor: column("context", results),
                                                    row: 0), false)
    }

    // MARK: - The find history

    /// Each phrase searched for goes to the front of the history, which is kept in the defaults, and offered by the
    /// find box
    func testRemembersWhatWasSearchedFor() throws {
        let (controller, defaults, window) = try makeController()
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        try findAll("flask", with: controller)
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["flask", "beaker"])
        XCTAssertEqual(historyItems(window), ["flask", "beaker"])
    }

    /// The history starts as the defaults have it
    func testTheHistoryStartsAsTheDefaultsHaveIt() throws {
        let (_, _, window) = try makeController(history: ["flask", "beaker"])
        XCTAssertEqual(historyItems(window), ["flask", "beaker"])
    }

    /// A phrase searched for again moves to the front
    func testAPhraseSearchedForAgainMovesToTheFront() throws {
        let (controller, defaults, window) = try makeController(history: ["flask", "beaker", "bottle"])
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker", "flask", "bottle"])
        XCTAssertEqual(historyItems(window), ["beaker", "flask", "bottle"])
    }

    /// The history is kept with the Find panel's, so what that adds after this is made is offered, and kept when this
    /// adds to it
    func testTheHistoryKeepsWhatTheFindPanelAdds() throws {
        let (controller, defaults, window) = try makeController(history: ["flask"])
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        defaults.set(["bottle", "flask"], forKey: "IFFindHistory")
        XCTAssertEqual(historyItems(window), ["bottle", "flask"])
        try findAll("beaker", with: controller)
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker", "bottle", "flask"])
        XCTAssertEqual(historyItems(window), ["beaker", "bottle", "flask"])
    }

    /// The history keeps the last thirty phrases
    func testTheHistoryKeepsThirtyPhrases() throws {
        let history = (1...30).map { "phrase \($0)" }
        let (controller, defaults, _) = try makeController(history: history)
        controller.setProject(try openProject(source: ["story.ni": "A beaker."]))
        try findAll("beaker", with: controller)
        XCTAssertEqual(defaults.object(forKey: "IFFindHistory") as? [String], ["beaker"] + history.dropLast())
    }

    /// The find box is offered nothing past the history
    func testNothingIsOfferedPastTheHistory() throws {
        let (_, _, window) = try makeController(history: ["flask"])
        let box = phraseBox(window)
        XCTAssertNil(box.dataSource?.comboBox?(box, objectValueForItemAt: 1))
        XCTAssertNil(box.dataSource?.comboBox?(box, objectValueForItemAt: -1))
    }

    /// Another combo box is offered nothing
    func testAnotherComboBoxIsOfferedNothing() throws {
        let (_, _, window) = try makeController(history: ["flask"])
        let box = phraseBox(window)
        let other = NSComboBox()
        XCTAssertEqual(box.dataSource?.numberOfItems?(in: other), 0)
        XCTAssertNil(box.dataSource?.comboBox?(other, objectValueForItemAt: 0))
    }
}
