//
//  IFColourPreferencesTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFColourPreferencesTests.never-written")!
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

/// The Colour pane's controls, from its nib
@MainActor
private struct Controls {
    let enableSyntaxColouring: NSButton
    let styles: NSPopUpButton
    let deleteStyle: NSButton
    let restoreSettings: NSButton
    let preview: NSTextView
    let sourceColour: NSColorWell
    let extensionColour: NSColorWell
    let headingsColour: NSColorWell
    let mainTextColour: NSColorWell
    let commentsColour: NSColorWell
    let quotedTextColour: NSColorWell
    let textSubstitutionsColour: NSColorWell

    init(_ pane: IFColourPreferences) throws {
        func control<T>(_ name: String) throws -> T {
            return try XCTUnwrap(pane.value(forKey: name) as? T, name)
        }
        enableSyntaxColouring = try control("enableSyntaxColouringButton")
        styles = try control("styleButton")
        deleteStyle = try control("deleteStyleButton")
        restoreSettings = try control("restoreSettingsButton")
        preview = try control("previewView")
        sourceColour = try control("sourceColour")
        extensionColour = try control("extensionColor")
        headingsColour = try control("headingsColor")
        mainTextColour = try control("mainTextColor")
        commentsColour = try control("commentsColor")
        quotedTextColour = try control("quotedTextColor")
        textSubstitutionsColour = try control("textSubstitutionsColor")
    }

    /// The colour wells, with the colour of the current theme each shows
    var wells: [(well: NSColorWell, name: String, colour: (IFPreferences) -> NSColor)] {
        return [(sourceColour, "source paper", { $0.sourcePaper.colour }),
                (extensionColour, "extension paper", { $0.extensionPaper.colour }),
                (headingsColour, "headings", { $0.sourcePaper(for: .headings).colour }),
                (mainTextColour, "main text", { $0.sourcePaper(for: .mainText).colour }),
                (commentsColour, "comments", { $0.sourcePaper(for: .comments).colour }),
                (quotedTextColour, "quoted text", { $0.sourcePaper(for: .quotedText).colour }),
                (textSubstitutionsColour, "text substitutions", { $0.sourcePaper(for: .textSubstitutions).colour })]
    }
}

@MainActor
final class IFColourPreferencesTests: XCTestCase {
    private let standardThemes = ["Light Mode", "Dark Mode", "Seven Seas", "Traditional"]
    private let types: [IFSyntaxHighlightingOptionType] = [.headings, .mainText, .comments, .quotedText, .textSubstitutions]

    /// A pane for preferences kept in memory, which start with the values given
    private func makePane(_ stored: [String: Any] = [:]) throws -> (IFColourPreferences, IFPreferences, MemoryDefaults, Controls) {
        let defaults = MemoryDefaults([IFPreferencesDefault: stored])
        let preferences = IFPreferences(userDefaults: defaults)
        let pane = IFColourPreferences(preferences: preferences)
        return (pane, preferences, defaults, try Controls(pane))
    }

    /// The dictionary the preferences last wrote to their user defaults
    private func written(_ defaults: MemoryDefaults) -> [String: Any] {
        return defaults.values[IFPreferencesDefault] as? [String: Any] ?? [:]
    }

    /// A colour's components, compared as the themes compare them
    private func components(_ colour: NSColor?) -> [Double] {
        guard let rgb = colour?.usingColorSpace(.genericRGB) else { return [] }
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent].map { (Double($0) * 1000).rounded() }
    }

    private func assertSameColour(_ colour: NSColor?, _ expected: NSColor?, _ message: String = "",
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(components(expected).isEmpty, message, file: file, line: line)
        XCTAssertEqual(components(colour), components(expected), message, file: file, line: line)
    }

    /// Changes a colour well's colour, as its user would with the colour panel
    private func change(_ well: NSColorWell, to colour: NSColor) {
        well.color = colour
        NSApp.sendAction(well.action!, to: well.target, from: well)
    }

    /// Chooses a theme from the menu, as its user would
    private func choose(_ theme: String, in popUp: NSPopUpButton) {
        popUp.selectItem(withTitle: theme)
        NSApp.sendAction(popUp.action!, to: popUp.target, from: popUp)
    }

    private let mauve = NSColor(deviceRed: 0.6, green: 0.4, blue: 0.7, alpha: 1.0)

    // MARK: - The toolbar item

    func testThePaneIsNamedColour() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.preferenceName, "Colour")
        XCTAssertNotNil(pane.toolbarImage)
    }

    /// The tooltip is the one in the localised strings, not its key
    func testThePanesTooltipIsLocalised() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.tooltip, IFUtility.localizedString("Colour preferences tooltip"))
        XCTAssertNotEqual(pane.tooltip, "Colour preferences tooltip")
        XCTAssertNotEqual(pane.tooltip, "Color preferences tooltip")
    }

    /// The pane can be as tall as the window allows, so that its preview grows
    func testThePaneCanBeAnyHeightAboveItsSmallest() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.maxHeight, .greatestFiniteMagnitude)
        XCTAssertEqual(pane.minHeight, 322)
        XCTAssertNotNil(pane.preferenceView)
    }

    // MARK: - Showing the preferences

    func testTheMenuListsTheThemes() throws {
        let (_, _, _, controls) = try makePane()
        XCTAssertEqual(controls.styles.itemTitles, standardThemes)
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Light Mode")
    }

    func testTheMenuShowsTheCurrentTheme() throws {
        let (_, _, _, controls) = try makePane(["currentThemeName": "Seven Seas"])
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Seven Seas")
    }

    func testTheWellsShowTheCurrentThemesColours() throws {
        for theme in standardThemes {
            let (_, preferences, _, controls) = try makePane(["currentThemeName": theme])
            for (well, name, colour) in controls.wells {
                assertSameColour(well.color, colour(preferences), "\(theme): \(name)")
            }
        }
    }

    func testThePreviewIsOnTheSourcePaper() throws {
        let (_, preferences, _, controls) = try makePane(["currentThemeName": "Dark Mode"])
        assertSameColour(controls.preview.backgroundColor, preferences.sourcePaper.colour)
        XCTAssertFalse(controls.preview.string.isEmpty)
    }

    /// With syntax colouring off, the colours can't be changed
    func testTheSyntaxColouringCheckBoxShowsThePreference() throws {
        let (_, _, _, on) = try makePane()
        XCTAssertEqual(on.enableSyntaxColouring.state, .on)
        for (well, name, _) in on.wells {
            XCTAssertTrue(well.isEnabled, name)
        }

        let (_, _, _, off) = try makePane(["enableSyntaxColouring": false])
        XCTAssertEqual(off.enableSyntaxColouring.state, .off)
        for (well, name, _) in off.wells {
            XCTAssertFalse(well.isEnabled, name)
        }
    }

    func testAStandardThemeCantBeDeleted() throws {
        for theme in standardThemes {
            let (_, _, _, controls) = try makePane(["currentThemeName": theme])
            XCTAssertFalse(controls.deleteStyle.isEnabled, theme)
        }
    }

    /// Restore is only enabled once a colour differs from the theme's default
    func testRestoreIsOnlyEnabledOnceAColourChanges() throws {
        let (_, _, _, controls) = try makePane()
        XCTAssertFalse(controls.restoreSettings.isEnabled)

        change(controls.commentsColour, to: mauve)

        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    /// The pane shows changes made elsewhere
    func testThePaneFollowsThePreferences() throws {
        let (_, preferences, _, controls) = try makePane()

        XCTAssertTrue(preferences.setCurrentTheme("Traditional"))
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Traditional")
        assertSameColour(controls.headingsColour.color, preferences.sourcePaper(for: .headings).colour)

        preferences.setSourceColour(mauve, for: .quotedText)
        assertSameColour(controls.quotedTextColour.color, mauve)

        preferences.enableSyntaxColouring = false
        XCTAssertEqual(controls.enableSyntaxColouring.state, .off)
        XCTAssertFalse(controls.headingsColour.isEnabled)
    }

    /// Only the preferences given are shown, not the shared ones
    func testThePaneIgnoresOtherPreferences() throws {
        let (_, _, _, controls) = try makePane()
        let other = IFPreferences(userDefaults: MemoryDefaults())

        XCTAssertTrue(other.setCurrentTheme("Dark Mode"))

        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Light Mode")
    }

    // MARK: - Setting the preferences

    func testChoosingAThemeMakesItCurrent() throws {
        let (_, preferences, defaults, controls) = try makePane()

        choose("Seven Seas", in: controls.styles)

        XCTAssertEqual(preferences.currentThemeName, "Seven Seas")
        XCTAssertEqual(written(defaults)["currentThemeName"] as? String, "Seven Seas")
        for (well, name, colour) in controls.wells {
            assertSameColour(well.color, colour(preferences), name)
        }
        assertSameColour(controls.preview.backgroundColor, preferences.sourcePaper.colour)
    }

    /// Each well sets its colour in the current theme, and only that colour
    func testEachWellSetsItsColour() throws {
        let count = try makePane().3.wells.count
        for index in 0..<count {
            let (_, preferences, defaults, controls) = try makePane(["currentThemeName": "Dark Mode"])
            let before = controls.wells.map { $0.colour(preferences) }
            let (well, name, colour) = controls.wells[index]

            change(well, to: mauve)

            for (other, original) in zip(controls.wells, before) where other.well !== well {
                assertSameColour(other.colour(preferences), original, "\(name) changed \(other.name)")
            }
            assertSameColour(colour(preferences), mauve, name)
            XCTAssertNotNil(written(defaults)["themes"], name)
            XCTAssertEqual(preferences.currentThemeName, "Dark Mode", name)
        }
    }

    /// A text colour is kept when whether to colour syntax hasn't been saved, as it isn't until its check box is
    /// used: saving that while copying the theme to the preferences reloaded the pane's theme from them before its
    /// text colours were copied
    func testATextColourIsKeptBeforeSyntaxColouringIsSaved() throws {
        let (_, preferences, defaults, controls) = try makePane()
        XCTAssertNil(written(defaults)["enableSyntaxColouring"])

        change(controls.headingsColour, to: mauve)

        assertSameColour(preferences.sourcePaper(for: .headings).colour, mauve)
        assertSameColour(controls.headingsColour.color, mauve)
        XCTAssertTrue(controls.restoreSettings.isEnabled)
    }

    /// Changing a colour of a theme leaves the other themes alone
    func testChangingAColourLeavesTheOtherThemesAlone() throws {
        let (_, preferences, _, controls) = try makePane()

        change(controls.headingsColour, to: mauve)
        XCTAssertTrue(preferences.setCurrentTheme("Dark Mode"))

        XCTAssertFalse(components(preferences.sourcePaper(for: .headings).colour) == components(mauve))
        XCTAssertTrue(preferences.setCurrentTheme("Light Mode"))
        assertSameColour(preferences.sourcePaper(for: .headings).colour, mauve)
    }

    func testUntickingSyntaxColouringTurnsItOff() throws {
        let (_, preferences, defaults, controls) = try makePane()

        controls.enableSyntaxColouring.performClick(nil)

        XCTAssertFalse(preferences.enableSyntaxColouring)
        XCTAssertEqual(written(defaults)["enableSyntaxColouring"] as? Bool, false)
        for (well, name, _) in controls.wells {
            XCTAssertFalse(well.isEnabled, name)
        }

        controls.enableSyntaxColouring.performClick(nil)

        XCTAssertTrue(preferences.enableSyntaxColouring)
        XCTAssertTrue(controls.headingsColour.isEnabled)
    }

    // MARK: - Adding, deleting and restoring themes

    /// A new theme is a copy of the current one's colours, and can be deleted
    func testAddingAThemeCopiesTheCurrentOne() throws {
        let (pane, preferences, _, controls) = try makePane(["currentThemeName": "Dark Mode"])
        change(controls.commentsColour, to: mauve)
        let colours = controls.wells.map { $0.colour(preferences) }

        XCTAssertTrue(pane.addThemeNamed("Mine"))

        XCTAssertEqual(preferences.themeNames, standardThemes + ["Mine"])
        XCTAssertEqual(preferences.currentThemeName, "Mine")
        XCTAssertEqual(controls.styles.itemTitles, standardThemes + ["Mine"])
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Mine")
        for ((_, name, colour), original) in zip(controls.wells, colours) {
            assertSameColour(colour(preferences), original, name)
        }
        XCTAssertEqual((preferences.getCurrentTheme().flags?.intValue ?? 0) & 1, 1)
        XCTAssertTrue(controls.deleteStyle.isEnabled)
    }

    /// A new theme's colours are its own
    func testANewThemesColoursAreItsOwn() throws {
        let (pane, preferences, _, controls) = try makePane()
        XCTAssertTrue(pane.addThemeNamed("Mine"))

        change(controls.headingsColour, to: mauve)
        XCTAssertTrue(preferences.setCurrentTheme("Light Mode"))

        XCTAssertFalse(components(preferences.sourcePaper(for: .headings).colour) == components(mauve))
    }

    func testAThemeCantBeAddedWithANameInUse() throws {
        let (pane, preferences, _, controls) = try makePane(["currentThemeName": "Seven Seas"])

        XCTAssertFalse(pane.addThemeNamed("Dark Mode"))

        XCTAssertEqual(preferences.themeNames, standardThemes)
        XCTAssertEqual(preferences.currentThemeName, "Seven Seas")
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Seven Seas")
    }

    func testDeletingTheCurrentThemeChoosesLightMode() throws {
        let (pane, preferences, _, controls) = try makePane(["currentThemeName": "Dark Mode"])
        XCTAssertTrue(pane.addThemeNamed("Mine"))

        pane.deleteCurrentTheme()

        XCTAssertEqual(preferences.themeNames, standardThemes)
        XCTAssertEqual(preferences.currentThemeName, "Light Mode")
        XCTAssertEqual(controls.styles.itemTitles, standardThemes)
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Light Mode")
        XCTAssertFalse(controls.deleteStyle.isEnabled)
    }

    func testAStandardThemeIsntDeleted() throws {
        let (pane, preferences, _, controls) = try makePane(["currentThemeName": "Dark Mode"])

        pane.deleteCurrentTheme()

        XCTAssertEqual(preferences.themeNames, standardThemes)
        XCTAssertEqual(preferences.currentThemeName, "Dark Mode")
        XCTAssertEqual(controls.styles.titleOfSelectedItem, "Dark Mode")
    }

    /// Restoring puts back the theme's default colours and turns syntax colouring back on
    func testRestoringPutsBackTheDefaults() throws {
        let (pane, preferences, _, controls) = try makePane(["currentThemeName": "Dark Mode"])
        let defaults = controls.wells.map { $0.colour(preferences) }
        for (well, _, _) in controls.wells {
            change(well, to: mauve)
        }
        controls.enableSyntaxColouring.performClick(nil)
        XCTAssertFalse(preferences.enableSyntaxColouring)

        pane.restoreDefaults()

        for ((well, name, colour), original) in zip(controls.wells, defaults) {
            assertSameColour(colour(preferences), original, name)
            assertSameColour(well.color, original, name)
            XCTAssertTrue(well.isEnabled, name)
        }
        XCTAssertTrue(preferences.enableSyntaxColouring)
        XCTAssertEqual(controls.enableSyntaxColouring.state, .on)
        XCTAssertFalse(controls.restoreSettings.isEnabled)
        XCTAssertEqual(preferences.currentThemeName, "Dark Mode")
    }
}
