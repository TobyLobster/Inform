//
//  IFEditingPreferencesTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFEditingPreferencesTests.never-written")!
    }

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

/// Counts the preferences' Editing notifications from one object, each of which re-highlights the open source views
private final class EditingNotificationCounter: @unchecked Sendable {
    private(set) var count = 0
    private var observer: NSObjectProtocol?

    init(_ object: AnyObject) {
        observer = NotificationCenter.default.addObserver(forName: .IFPreferencesEditingDidChange,
                                                          object: object,
                                                          queue: nil) { [weak self] _ in
            self?.count += 1
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

/// The controls for one type of text in the pane's syntax highlighting section
private struct Row {
    let type: IFSyntaxHighlightingOptionType
    let name: String
    let label: NSTextField
    let bold: NSButton
    let italic: NSButton
    let underline: NSButton
    let size: NSSlider

    var controls: [NSControl] {
        return [label, bold, italic, underline, size]
    }
}

/// The Editing pane's controls, from its nib
private struct Controls {
    let fontFamily: NSTextField
    let appTextSize: NSSlider
    let enableSyntaxHighlighting: NSButton
    let restoreSettings: NSButton
    let rows: [Row]
    let tabStop: NSSlider
    let preview: NSTextView
    let tabStopView: NSTextView
    let autoIndent: NSButton
    let autoSpace: NSButton
    let autoNumber: NSButton

    init(_ pane: IFEditingPreferences) throws {
        func control<T>(_ name: String) throws -> T {
            return try XCTUnwrap(pane.value(forKey: name) as? T, name)
        }
        fontFamily = try control("fontFamily")
        appTextSize = try control("appTextSize")
        enableSyntaxHighlighting = try control("enableSyntaxHighlighting")
        restoreSettings = try control("restoreSettingsButton")
        let types: [(IFSyntaxHighlightingOptionType, String, String)] = [(.headings, "headings", "Headings"),
                                                                        (.mainText, "mainText", "MainText"),
                                                                        (.comments, "comments", "Comments"),
                                                                        (.quotedText, "quotedText", "QuotedText"),
                                                                        (.textSubstitutions, "textSubstitutions", "TextSubstitutions")]
        rows = try types.map { type, name, row in
            Row(type: type,
                name: name,
                label: try control("row\(row)"),
                bold: try control("\(name)Bold"),
                italic: try control("\(name)Italic"),
                underline: try control("\(name)Underline"),
                size: try control("\(name)FontSize"))
        }
        tabStop = try control("tabStopSlider")
        preview = try control("previewView")
        tabStopView = try control("tabStopView")
        autoIndent = try control("autoIndentAfterNewline")
        autoSpace = try control("autoSpaceTableColumns")
        autoNumber = try control("autoNumberSections")
    }

    func row(_ type: IFSyntaxHighlightingOptionType) -> Row {
        return rows.first { $0.type == type }!
    }
}

@MainActor
final class IFEditingPreferencesTests: XCTestCase {
    private let types: [IFSyntaxHighlightingOptionType] = [.headings, .mainText, .comments, .quotedText, .textSubstitutions]

    /// A pane for preferences kept in memory, set up as given
    private func makePane(_ setUp: (IFPreferences) -> Void = { _ in }) throws -> (IFEditingPreferences, IFPreferences, MemoryDefaults, Controls) {
        let defaults = MemoryDefaults()
        let preferences = IFPreferences(userDefaults: defaults)
        setUp(preferences)
        let pane = IFEditingPreferences(preferences: preferences)
        return (pane, preferences, defaults, try Controls(pane))
    }

    /// The dictionary the preferences last wrote to their user defaults
    private func written(_ defaults: MemoryDefaults) -> [String: Any] {
        return defaults.values[IFPreferencesDefault] as? [String: Any] ?? [:]
    }

    /// Sets a check box, as its user would
    private func set(_ button: NSButton, _ on: Bool) {
        button.state = on ? .on : .off
        NSApp.sendAction(button.action!, to: button.target, from: button)
    }

    /// Moves a slider, as its user would
    private func slide(_ slider: NSSlider, to value: Double) {
        slider.doubleValue = value
        NSApp.sendAction(slider.action!, to: slider.target, from: slider)
    }

    /// Whether the preferences have the default editing preferences
    private func haveTheDefaults(_ preferences: IFPreferences) -> Bool {
        let set = IFEditingPreferencesSet()
        set.updateSet(from: preferences)
        return set.isEqual(toPreferenceSet: IFEditingPreferencesSet())
    }

    // MARK: - The toolbar item

    func testThePaneIsNamedEditing() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.preferenceName, "Editing")
        XCTAssertNotNil(pane.toolbarImage)
    }

    /// The tooltip is the one in the localised strings, not its key
    func testThePanesTooltipIsLocalised() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.tooltip, IFUtility.localizedString("Editing preferences tooltip"))
        XCTAssertNotEqual(pane.tooltip, "Editing preferences tooltip")
    }

    /// The pane can be as tall as the window allows, so that its preview grows
    func testThePaneCanBeAnyHeightAboveItsSmallest() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.maxHeight, .greatestFiniteMagnitude)
        XCTAssertEqual(pane.minHeight, 574)
        XCTAssertNotNil(pane.preferenceView)
    }

    // MARK: - Showing the preferences

    func testTheControlsShowTheDefaults() throws {
        let (_, _, _, controls) = try makePane()

        XCTAssertEqual(controls.fontFamily.stringValue, "Lucida Grande - 12")
        XCTAssertEqual(controls.appTextSize.intValue, IFAppFontSize.normal.rawValue)
        XCTAssertEqual(controls.enableSyntaxHighlighting.state, .on)
        for row in controls.rows {
            XCTAssertEqual(row.bold.state, .off, row.name)
            XCTAssertEqual(row.italic.state, .off, row.name)
            XCTAssertEqual(row.underline.state, row.type == .headings ? .on : .off, row.name)
            let size: IFRelativeFontSize = row.type == .headings ? .fontSizePlus10 : .fontSizeNormal
            XCTAssertEqual(row.size.intValue, size.rawValue, row.name)
            for control in row.controls {
                XCTAssertTrue(control.isEnabled, row.name)
            }
        }
        XCTAssertEqual(controls.tabStop.doubleValue, 24)
        XCTAssertEqual(controls.autoIndent.state, .on)
        XCTAssertEqual(controls.autoSpace.state, .on)
        XCTAssertEqual(controls.autoNumber.state, .on)
        XCTAssertFalse(controls.restoreSettings.isEnabled)
    }

    func testTheControlsShowThePreferences() throws {
        let (_, _, _, controls) = try makePane { preferences in
            preferences.sourceFontFamily = "Menlo"
            preferences.sourceFontSize = 15
            preferences.appFontSizeMultiplierEnum = .plus50
            preferences.setSourceFontStyle(.bold, for: .mainText)
            preferences.setSourceFontStyle(.italic, for: .comments)
            preferences.setSourceFontStyle(.boldItalic, for: .quotedText)
            preferences.setSourceUnderline(false, for: .headings)
            preferences.setSourceUnderline(true, for: .textSubstitutions)
            preferences.setSourceRelativeFontSize(.fontSizeMinus20, for: .comments)
            preferences.setSourceRelativeFontSize(.fontSizePlus30, for: .headings)
            preferences.tabWidth = 40
            preferences.indentAfterNewline = false
            preferences.elasticTabs = false
            preferences.autoNumberSections = false
        }

        XCTAssertEqual(controls.fontFamily.stringValue, "Menlo - 15")
        XCTAssertEqual(controls.appTextSize.intValue, IFAppFontSize.plus50.rawValue)
        XCTAssertEqual(controls.row(.headings).bold.state, .off)
        XCTAssertEqual(controls.row(.mainText).bold.state, .on)
        XCTAssertEqual(controls.row(.mainText).italic.state, .off)
        XCTAssertEqual(controls.row(.comments).bold.state, .off)
        XCTAssertEqual(controls.row(.comments).italic.state, .on)
        XCTAssertEqual(controls.row(.quotedText).bold.state, .on)
        XCTAssertEqual(controls.row(.quotedText).italic.state, .on)
        XCTAssertEqual(controls.row(.headings).underline.state, .off)
        XCTAssertEqual(controls.row(.textSubstitutions).underline.state, .on)
        XCTAssertEqual(controls.row(.comments).size.intValue, IFRelativeFontSize.fontSizeMinus20.rawValue)
        XCTAssertEqual(controls.row(.headings).size.intValue, IFRelativeFontSize.fontSizePlus30.rawValue)
        XCTAssertEqual(controls.tabStop.doubleValue, 40)
        XCTAssertEqual(controls.autoIndent.state, .off)
        XCTAssertEqual(controls.autoSpace.state, .off)
        XCTAssertEqual(controls.autoNumber.state, .off)
        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    /// With syntax highlighting off, the styles can't be changed
    func testTheStylesCantBeChangedWithoutSyntaxHighlighting() throws {
        let (_, _, _, controls) = try makePane { $0.enableSyntaxHighlighting = false }

        XCTAssertEqual(controls.enableSyntaxHighlighting.state, .off)
        for row in controls.rows {
            for control in row.controls {
                XCTAssertFalse(control.isEnabled, row.name)
            }
        }
        XCTAssertTrue(controls.tabStop.isEnabled)
        XCTAssertTrue(controls.autoIndent.isEnabled)
    }

    /// The text size is shown, but isn't one of the editing preferences that Restore puts back
    func testTheTextSizeDoesntEnableRestore() throws {
        let (_, _, _, controls) = try makePane { $0.appFontSizeMultiplierEnum = .minus25 }

        XCTAssertEqual(controls.appTextSize.intValue, IFAppFontSize.minus25.rawValue)
        XCTAssertFalse(controls.restoreSettings.isEnabled)
    }

    func testThePreviewIsOnTheSourcePaper() throws {
        let (_, preferences, _, controls) = try makePane { XCTAssertTrue($0.setCurrentTheme("Dark Mode")) }

        XCTAssertEqual(controls.preview.backgroundColor, preferences.sourcePaper.colour)
        XCTAssertFalse(controls.preview.string.isEmpty)
        XCTAssertFalse(controls.tabStopView.string.isEmpty)
    }

    /// The tab slider goes as far as its width allows
    func testTheTabSliderGoesAsFarAsItsWidthAllows() throws {
        let (_, _, _, controls) = try makePane()

        XCTAssertEqual(controls.tabStop.maxValue, Double(controls.tabStop.bounds.width - 12))
        XCTAssertGreaterThan(controls.tabStop.maxValue, 24)
    }

    /// The pane shows changes made elsewhere
    func testThePaneFollowsThePreferences() throws {
        let (_, preferences, _, controls) = try makePane()

        preferences.sourceFontFamily = "Menlo"
        XCTAssertEqual(controls.fontFamily.stringValue, "Menlo - 12")

        preferences.setSourceFontStyle(.bold, for: .comments)
        XCTAssertEqual(controls.row(.comments).bold.state, .on)

        preferences.autoNumberSections = false
        XCTAssertEqual(controls.autoNumber.state, .off)
        XCTAssertTrue(controls.restoreSettings.isEnabled)

        preferences.enableSyntaxHighlighting = false
        XCTAssertEqual(controls.enableSyntaxHighlighting.state, .off)
        XCTAssertFalse(controls.row(.headings).bold.isEnabled)
    }

    /// Only the preferences given are shown, not others
    func testThePaneIgnoresOtherPreferences() throws {
        let (_, _, _, controls) = try makePane()
        let other = IFPreferences(userDefaults: MemoryDefaults())

        other.sourceFontFamily = "Menlo"

        XCTAssertEqual(controls.fontFamily.stringValue, "Lucida Grande - 12")
    }

    // MARK: - Setting the preferences

    func testTheSyntaxHighlightingCheckBoxSetsThePreference() throws {
        let (_, preferences, defaults, controls) = try makePane()

        set(controls.enableSyntaxHighlighting, false)

        XCTAssertFalse(preferences.enableSyntaxHighlighting)
        XCTAssertEqual(written(defaults)["enableSyntaxHighlighting"] as? Bool, false)
        for row in controls.rows {
            for control in row.controls {
                XCTAssertFalse(control.isEnabled, row.name)
            }
        }
        XCTAssertTrue(controls.restoreSettings.isEnabled)

        set(controls.enableSyntaxHighlighting, true)

        XCTAssertTrue(preferences.enableSyntaxHighlighting)
        for row in controls.rows {
            for control in row.controls {
                XCTAssertTrue(control.isEnabled, row.name)
            }
        }
        XCTAssertFalse(controls.restoreSettings.isEnabled)
    }

    /// Each row's Bold and Italic buttons set its style, and only its
    func testEachRowsBoldAndItalicButtonsSetItsStyle() throws {
        for type in types {
            let (_, preferences, _, controls) = try makePane()
            let row = controls.row(type)

            set(row.bold, true)
            XCTAssertEqual(preferences.sourceFontStyle(for: type), .bold, row.name)

            set(row.italic, true)
            XCTAssertEqual(preferences.sourceFontStyle(for: type), .boldItalic, row.name)

            set(row.bold, false)
            XCTAssertEqual(preferences.sourceFontStyle(for: type), .italic, row.name)
            XCTAssertTrue(controls.restoreSettings.isEnabled, row.name)

            for other in types where other != type {
                XCTAssertEqual(preferences.sourceFontStyle(for: other), .regular, "\(row.name) changed \(other.rawValue)")
            }
        }
    }

    /// Each row's Underline button sets its underlining, and only its
    func testEachRowsUnderlineButtonSetsItsUnderlining() throws {
        for type in types {
            let (_, preferences, _, controls) = try makePane()
            let row = controls.row(type)
            let before = types.map { preferences.sourceUnderline(for: $0) }

            set(row.underline, row.underline.state == .off)

            for (other, was) in zip(types, before) {
                XCTAssertEqual(preferences.sourceUnderline(for: other), other == type ? !was : was, "\(row.name): \(other.rawValue)")
            }
            XCTAssertTrue(controls.restoreSettings.isEnabled, row.name)
        }
    }

    /// Each row's slider sets its size, and only its
    func testEachRowsSliderSetsItsSize() throws {
        for type in types {
            let (_, preferences, _, controls) = try makePane()
            let row = controls.row(type)
            let before = types.map { preferences.sourceRelativeFontSize(for: $0) }

            slide(row.size, to: Double(IFRelativeFontSize.fontSizeMinus30.rawValue))

            for (other, was) in zip(types, before) {
                XCTAssertEqual(preferences.sourceRelativeFontSize(for: other), other == type ? .fontSizeMinus30 : was, "\(row.name): \(other.rawValue)")
            }
            XCTAssertTrue(controls.restoreSettings.isEnabled, row.name)
        }
    }

    /// A change is kept before the editing preferences have been saved, as they aren't until the pane first sets
    /// them: saving the font family, which is copied first, reloaded the pane's settings from the preferences before
    /// the change was copied
    func testTheFirstChangeIsKeptBeforeThePreferencesAreSaved() throws {
        let (_, preferences, defaults, controls) = try makePane()
        XCTAssertNil(written(defaults)["sourceFontFamily"])

        set(controls.row(.comments).underline, true)

        XCTAssertTrue(preferences.sourceUnderline(for: .comments))
        XCTAssertEqual(controls.row(.comments).underline.state, .on)
        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    func testTheTabSliderSetsTheTabWidth() throws {
        let (_, preferences, defaults, controls) = try makePane()

        slide(controls.tabStop, to: 40)

        XCTAssertEqual(preferences.tabWidth, 40)
        XCTAssertEqual(written(defaults)["tabWidth"] as? Double, 40)
        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    /// The indenting and numbering check boxes each set their preference, and only theirs
    func testTheIndentingAndNumberingCheckBoxesSetTheirPreferences() throws {
        let checkBoxes: [(name: String, button: (Controls) -> NSButton, value: (IFPreferences) -> Bool)] = [
            ("indent after newline", { $0.autoIndent }, { $0.indentAfterNewline }),
            ("space table columns", { $0.autoSpace }, { $0.elasticTabs }),
            ("number sections", { $0.autoNumber }, { $0.autoNumberSections }),
        ]
        for checkBox in checkBoxes {
            let (_, preferences, _, controls) = try makePane()

            set(checkBox.button(controls), false)

            XCTAssertFalse(checkBox.value(preferences), checkBox.name)
            for other in checkBoxes where other.name != checkBox.name {
                XCTAssertTrue(other.value(preferences), "\(checkBox.name) changed \(other.name)")
            }
            XCTAssertTrue(controls.restoreSettings.isEnabled, checkBox.name)

            set(checkBox.button(controls), true)

            XCTAssertTrue(checkBox.value(preferences), checkBox.name)
            XCTAssertFalse(controls.restoreSettings.isEnabled, checkBox.name)
        }
    }

    /// The text size slider sets the size of the app's text, which isn't an editing preference
    func testTheTextSizeSliderSetsTheAppsTextSize() throws {
        let (_, preferences, _, controls) = try makePane()
        let posted = expectation(forNotification: .IFPreferencesAppFontSizeDidChange, object: preferences)

        slide(controls.appTextSize, to: Double(IFAppFontSize.plus75.rawValue))

        wait(for: [posted], timeout: 0)
        XCTAssertEqual(preferences.appFontSizeMultiplierEnum, .plus75)
        XCTAssertTrue(haveTheDefaults(preferences))
        XCTAssertFalse(controls.restoreSettings.isEnabled)
    }

    /// The font chosen in the Font panel is shown as its family and size, which the pane then sets
    func testTheFontShownIsSet() throws {
        let (pane, preferences, _, controls) = try makePane()

        controls.fontFamily.stringValue = "American Typewriter - 12"
        pane.styleSetHasChanged(controls.fontFamily)

        XCTAssertEqual(preferences.sourceFontFamily, "American Typewriter")
        XCTAssertEqual(preferences.sourceFontSize, 12)
        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    /// A new family and size are both set: setting the family reloaded the pane's settings from the preferences
    /// before the size was copied
    func testANewFamilyAndSizeAreBothSet() throws {
        let (pane, preferences, _, controls) = try makePane()

        controls.fontFamily.stringValue = "Menlo - 15"
        pane.styleSetHasChanged(controls.fontFamily)

        XCTAssertEqual(preferences.sourceFontFamily, "Menlo")
        XCTAssertEqual(preferences.sourceFontSize, 15)
        XCTAssertEqual(controls.fontFamily.stringValue, "Menlo - 15")
    }

    /// Text that isn't a family and a size sets neither
    func testTextThatIsntAFontSetsNothing() throws {
        let (pane, preferences, _, controls) = try makePane()

        controls.fontFamily.stringValue = "Menlo"
        pane.styleSetHasChanged(controls.fontFamily)

        XCTAssertEqual(preferences.sourceFontFamily, "Lucida Grande")
        XCTAssertEqual(preferences.sourceFontSize, 12)
    }

    /// Changing only the size in the Font panel keeps the font: the pane converted a bold system font, rather than
    /// the one the panel was given, so the font became the system font
    func testChangingOnlyTheFontsSizeKeepsTheFont() throws {
        let (pane, preferences, _, controls) = try makePane()
        let fontManager = NSFontManager.shared
        let panelExisted = NSFontPanel.sharedFontPanelExists
        let (target, action) = (fontManager.target, fontManager.action)
        defer {
            fontManager.target = target
            fontManager.action = action
        }
        // As showFontPicker: does, without showing the Font panel
        fontManager.target = pane
        fontManager.action = Selector(("selectFont:"))

        // As the Font panel does when its user changes only the size, but by one point, without the panel
        let bigger = NSMenuItem()
        bigger.tag = Int(NSFontAction.sizeUpFontAction.rawValue)
        fontManager.modifyFont(bigger)

        XCTAssertEqual(preferences.sourceFontFamily, "Lucida Grande")
        XCTAssertEqual(preferences.sourceFontSize, 13)
        XCTAssertEqual(controls.fontFamily.stringValue, "Lucida Grande - 13")
        if !panelExisted {
            XCTAssertFalse(NSFontPanel.sharedFontPanelExists)
        }
    }

    /// Restoring the defaults puts back every editing preference, and leaves the text size alone
    /// Restoring the defaults tells of the change once, so the source views are only re-highlighted once
    func testRestoringTheDefaultsTellsOnce() throws {
        let (pane, preferences, _, _) = try makePane { preferences in
            preferences.sourceFontFamily = "Menlo"
            preferences.tabWidth = 40
            preferences.elasticTabs = false
            preferences.setSourceFontStyle(.bold, for: .comments)
        }
        let counter = EditingNotificationCounter(preferences)

        pane.restoreDefaults()

        XCTAssertEqual(counter.count, 1)
    }

    func testRestoringTheDefaults() throws {
        let (pane, preferences, _, controls) = try makePane { preferences in
            preferences.sourceFontFamily = "Menlo"
            preferences.sourceFontSize = 15
            preferences.enableSyntaxHighlighting = false
            preferences.setSourceFontStyle(.bold, for: .comments)
            preferences.setSourceUnderline(false, for: .headings)
            preferences.setSourceRelativeFontSize(.fontSizeMinus20, for: .quotedText)
            preferences.tabWidth = 40
            preferences.indentAfterNewline = false
            preferences.elasticTabs = false
            preferences.autoNumberSections = false
            preferences.appFontSizeMultiplierEnum = .plus50
        }
        XCTAssertTrue(controls.restoreSettings.isEnabled)

        pane.restoreDefaults()

        XCTAssertTrue(haveTheDefaults(preferences))
        XCTAssertEqual(preferences.appFontSizeMultiplierEnum, .plus50)
        XCTAssertEqual(controls.fontFamily.stringValue, "Lucida Grande - 12")
        XCTAssertEqual(controls.enableSyntaxHighlighting.state, .on)
        XCTAssertEqual(controls.row(.comments).bold.state, .off)
        XCTAssertEqual(controls.row(.headings).underline.state, .on)
        XCTAssertEqual(controls.row(.quotedText).size.intValue, IFRelativeFontSize.fontSizeNormal.rawValue)
        XCTAssertEqual(controls.tabStop.doubleValue, 24)
        XCTAssertEqual(controls.autoNumber.state, .on)
        XCTAssertEqual(controls.appTextSize.intValue, IFAppFontSize.plus50.rawValue)
        XCTAssertFalse(controls.restoreSettings.isEnabled)
    }
}
