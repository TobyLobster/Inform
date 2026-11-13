//
//  IFPreferencesTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never write the user's own. The preferences only read and write
/// their one dictionary, with object(forKey:) and set(_:forKey:).
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]
    private(set) var writes = 0

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFPreferencesTests.never-written")!
    }

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
        writes += 1
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
        writes += 1
    }
}

/// Records the preferences' notifications posted by one object
private final class NotificationRecorder: @unchecked Sendable {
    private(set) var names: [NSNotification.Name] = []
    private var observers: [NSObjectProtocol] = []

    init(_ object: AnyObject) {
        for name: NSNotification.Name in [.IFPreferencesEditingDidChange, .IFPreferencesAdvancedDidChange,
                                          .IFPreferencesAppFontSizeDidChange, .IFPreferencesAuthorDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { [weak self] notification in
                self?.names.append(notification.name)
            })
        }
    }

    func clear() {
        names.removeAll()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@MainActor
final class IFPreferencesTests: XCTestCase {

    private let types: [IFSyntaxHighlightingOptionType] = [.headings, .mainText, .comments, .quotedText, .textSubstitutions]
    private let standardThemes = ["Light Mode", "Dark Mode", "Seven Seas", "Traditional"]

    private func makePreferences(_ stored: [String: Any]? = nil) -> (IFPreferences, MemoryDefaults) {
        let defaults = MemoryDefaults()
        if let stored {
            defaults.values[IFPreferencesDefault] = stored
        }
        return (IFPreferences(userDefaults: defaults), defaults)
    }

    /// The dictionary the preferences last wrote to their user defaults
    private func written(_ defaults: MemoryDefaults) -> [String: Any] {
        return defaults.values[IFPreferencesDefault] as? [String: Any] ?? [:]
    }

    /// The Objective-C type of a number written, which decides how the property list keeps it
    private func type(_ value: Any?) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return String(cString: number.objCType)
    }

    private func byteColour(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        return NSColor(deviceRed: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    private func themes(in data: Any?) throws -> [IFColourTheme] {
        let data = try XCTUnwrap(data as? Data)
        let classes: [AnyClass] = [NSArray.self, IFColourTheme.self, IFSyntaxColouringOption.self, NSString.self, NSNumber.self, NSColor.self]
        return try XCTUnwrap(try NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? [IFColourTheme])
    }

    private func archive(_ themes: [IFColourTheme]) throws -> Data {
        return try NSKeyedArchiver.archivedData(withRootObject: themes, requiringSecureCoding: true)
    }

    private func style(_ prefs: IFPreferences, _ style: IFSyntaxStyle) -> [NSAttributedString.Key: Any] {
        return prefs.styles[Int(style.rawValue)] as! [NSAttributedString.Key: Any]
    }

    // MARK: - Reading and writing

    /// The preferences are read from one dictionary in the user defaults
    func testPreferencesAreReadFromTheirDictionary() {
        let (prefs, _) = makePreferences(["sourceFontFamily": "Menlo", "tabWidth": 30.5, "runBuildSh": true])

        XCTAssertEqual(prefs.sourceFontFamily, "Menlo")
        XCTAssertEqual(prefs.tabWidth, 30.5)
        XCTAssertTrue(prefs.runBuildSh)
    }

    /// The Editing preferences' tab stop slider sets fractional widths, and the source view
    /// uses the width it reads back.
    func testReadsAFractionalTabWidthBack() {
        let (prefs, _) = makePreferences()

        prefs.tabWidth = 30.5

        XCTAssertEqual(prefs.tabWidth, 30.5)
    }

    /// With nothing saved, each preference has its default: the editing ones from a new editing preferences set
    func testEachPreferenceHasItsDefault() {
        let (prefs, _) = makePreferences()
        let editing = IFEditingPreferencesSet()

        XCTAssertEqual(prefs.sourceFontFamily, editing.fontFamily)
        XCTAssertEqual(prefs.sourceFontSize, CGFloat(editing.fontSize))
        XCTAssertEqual(prefs.tabWidth, editing.tabWidth)
        XCTAssertEqual(prefs.enableSyntaxHighlighting, editing.enableSyntaxHighlighting)
        XCTAssertEqual(prefs.elasticTabs, editing.autoSpaceTableColumns)
        XCTAssertEqual(prefs.indentAfterNewline, editing.autoIndentAfterNewline)
        XCTAssertEqual(prefs.autoNumberSections, editing.autoNumberSections)
        for type in types {
            XCTAssertEqual(prefs.sourceFontStyle(for: type), editing.option(of: type).fontStyle)
            XCTAssertEqual(prefs.sourceUnderline(for: type), editing.option(of: type).underline)
            XCTAssertEqual(prefs.sourceRelativeFontSize(for: type), editing.option(of: type).relativeFontSize)
        }

        XCTAssertEqual(prefs.appFontSizeMultiplierEnum, .normal)
        XCTAssertEqual(prefs.appFontSizeMultiplier, 1.0)
        XCTAssertEqual(prefs.currentThemeName, "Light Mode")
        XCTAssertTrue(prefs.enableSyntaxColouring)
        XCTAssertFalse(prefs.runBuildSh)
        XCTAssertFalse(prefs.alwaysCompile)
        XCTAssertFalse(prefs.showDebuggingLogs)
        XCTAssertFalse(prefs.showConsoleDuringBuilds)
        XCTAssertFalse(prefs.publicLibraryDebug)
        XCTAssertTrue(prefs.cleanProjectOnClose)
        XCTAssertFalse(prefs.alsoCleanIndexFiles)
        XCTAssertEqual(prefs.glulxInterpreter, "glulxe") // As Info.plist's InformConfiguration says
        XCTAssertFalse(prefs.useExternalInformCoreDirectory)
        XCTAssertEqual(prefs.externalInformCoreDirectory, "")
        XCTAssertEqual(prefs.preferencesTopLeftPosition, NSPoint(x: 50, y: 50))
    }

    /// A preference written as text, as `defaults write` writes it, is read as the number or truth it says
    func testPreferencesWrittenAsTextAreRead() {
        let (prefs, _) = makePreferences(["runBuildSh": "YES", "tabWidth": "30.5", "appFontSizeMultiplierFineEnum": "6",
                                          "sourceUnderline1": "1"])

        XCTAssertTrue(prefs.runBuildSh)
        XCTAssertEqual(prefs.tabWidth, 30.5)
        XCTAssertEqual(prefs.appFontSizeMultiplierEnum, .plus50)
        XCTAssertTrue(prefs.sourceUnderline(for: .mainText))
    }

    /// A preference of the wrong type, which only a damaged preferences file could have, reads as its default
    func testAPreferenceOfTheWrongTypeReadsAsItsDefault() {
        let data = Data([1, 2, 3])
        let (prefs, _) = makePreferences(["sourceFontFamily": 12, "currentThemeName": 12, "externalInformCoreDirectory": data,
                                          "newGameAuthorName": 12, "glulxInterpreter": 12,
                                          "appFontSizeMultiplierFineEnum": data, "sourceFontStyle0": data,
                                          "sourceFontSize": data, "tabWidth": data, "PreferencesWindowX": data,
                                          "cleanProjectOnClose": data, "sourceUnderline0": data])
        let userName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()

        XCTAssertEqual(prefs.sourceFontFamily, "Lucida Grande")
        XCTAssertEqual(prefs.currentThemeName, "Light Mode")
        XCTAssertEqual(prefs.externalInformCoreDirectory, "")
        XCTAssertEqual(prefs.freshGameAuthorName, userName)
        XCTAssertEqual(prefs.glulxInterpreter, "glulxe")
        XCTAssertEqual(prefs.appFontSizeMultiplierEnum, .normal)
        XCTAssertEqual(prefs.sourceFontStyle(for: .headings), .regular)
        XCTAssertEqual(prefs.sourceFontSize, 12)
        XCTAssertEqual(prefs.tabWidth, 24)
        XCTAssertEqual(prefs.preferencesTopLeftPosition, NSPoint(x: 50, y: 50))
        XCTAssertTrue(prefs.cleanProjectOnClose)
        XCTAssertTrue(prefs.sourceUnderline(for: .headings))
    }

    /// Preferences in the user defaults that aren't a dictionary are ignored
    func testPreferencesThatArentADictionaryAreIgnored() {
        let defaults = MemoryDefaults([IFPreferencesDefault: "Not a dictionary"])
        let prefs = IFPreferences(userDefaults: defaults)

        XCTAssertEqual(prefs.sourceFontFamily, "Lucida Grande")
        XCTAssertEqual(prefs.themeNames, standardThemes)
    }

    /// ...as are preferences that are a number, which can't be copied to change
    func testPreferencesThatAreANumberAreIgnored() {
        let defaults = MemoryDefaults([IFPreferencesDefault: 5])
        let prefs = IFPreferences(userDefaults: defaults)

        XCTAssertEqual(prefs.sourceFontFamily, "Lucida Grande")
        XCTAssertEqual(prefs.themeNames, standardThemes)
    }

    /// Each preference is written under its own key, as a number of its own type, and tells those watching it
    func testEachPreferenceIsWrittenUnderItsKeyWithItsNotification() {
        let editing = NSNotification.Name.IFPreferencesEditingDidChange
        let advanced = NSNotification.Name.IFPreferencesAdvancedDidChange
        let changes: [(key: String, value: Any, type: String?, notification: NSNotification.Name?, change: (IFPreferences) -> Void)] = [
            ("sourceFontFamily", "Menlo", nil, editing, { $0.sourceFontFamily = "Menlo" }),
            ("sourceFontSize", 15.5, "d", editing, { $0.sourceFontSize = 15.5 }),
            ("appFontSizeMultiplierFineEnum", 6, "i", .IFPreferencesAppFontSizeDidChange, { $0.appFontSizeMultiplierEnum = .plus50 }),
            ("tabWidth", 30.5, "d", editing, { $0.tabWidth = 30.5 }),
            ("currentThemeName", "Seven Seas", nil, editing, { $0.currentThemeName = "Seven Seas" }),
            ("sourceFontStyle2", 3, "i", editing, { $0.setSourceFontStyle(.boldItalic, for: .comments) }),
            ("sourceRelativeFontSize2", 6, "i", editing, { $0.setSourceRelativeFontSize(.fontSizePlus30, for: .comments) }),
            ("sourceUnderline2", true, "c", editing, { $0.setSourceUnderline(true, for: .comments) }),
            ("enableSyntaxHighlighting", false, "c", editing, { $0.enableSyntaxHighlighting = false }),
            ("enableSyntaxColouring", false, "c", editing, { $0.enableSyntaxColouring = false }),
            ("elasticTabs", false, "c", editing, { $0.elasticTabs = false }),
            ("indentAfterNewline", false, "c", editing, { $0.indentAfterNewline = false }),
            ("autoNumberSections", false, "c", editing, { $0.autoNumberSections = false }),
            ("newGameAuthorName", "Emily Short", nil, .IFPreferencesAuthorDidChange, { $0.freshGameAuthorName = "Emily Short" }),
            ("runBuildSh", true, "c", advanced, { $0.runBuildSh = true }),
            ("alwaysCompile", true, "c", advanced, { $0.alwaysCompile = true }),
            ("showDebuggingLogs", true, "c", advanced, { $0.showDebuggingLogs = true }),
            ("showConsoleDuringBuilds", true, "c", advanced, { $0.showConsoleDuringBuilds = true }),
            ("publicLibraryDebug", true, "c", advanced, { $0.publicLibraryDebug = true }),
            ("cleanProjectOnClose", false, "c", advanced, { $0.cleanProjectOnClose = false }),
            ("alsoCleanIndexFiles", true, "c", advanced, { $0.alsoCleanIndexFiles = true }),
            ("glulxInterpreter", "git", nil, advanced, { $0.glulxInterpreter = "git" }),
            ("useExternalInformCoreDirectory", true, "c", advanced, { $0.useExternalInformCoreDirectory = true }),
            ("externalInformCoreDirectory", "/Core", nil, advanced, { $0.externalInformCoreDirectory = "/Core" }),
            ("PreferencesWindowX", 120.5, "d", nil, { $0.preferencesTopLeftPosition = NSPoint(x: 120.5, y: 50) }),
            ("PreferencesWindowY", 80.5, "d", nil, { $0.preferencesTopLeftPosition = NSPoint(x: 50, y: 80.5) }),
        ]

        for change in changes {
            let (prefs, defaults) = makePreferences()
            let recorder = NotificationRecorder(prefs)
            let writes = defaults.writes

            change.change(prefs)

            let value = written(defaults)[change.key]
            XCTAssertEqual(value as? NSObject, change.value as? NSObject, change.key)
            XCTAssertEqual(type(value), change.type, change.key)
            XCTAssertGreaterThan(defaults.writes, writes, change.key)
            XCTAssertEqual(recorder.names, change.notification.map { [$0] } ?? [], change.key)
        }
    }

    /// Each preference is read back as it was set
    func testEachPreferenceIsReadBack() {
        let (prefs, _) = makePreferences()

        prefs.sourceFontFamily = "Menlo"
        prefs.sourceFontSize = 15.5
        prefs.appFontSizeMultiplierEnum = .minus25
        prefs.setSourceFontStyle(.bold, for: .quotedText)
        prefs.setSourceRelativeFontSize(.fontSizeMinus10, for: .quotedText)
        prefs.setSourceUnderline(true, for: .quotedText)
        prefs.enableSyntaxColouring = false
        prefs.elasticTabs = false
        prefs.alwaysCompile = true
        prefs.glulxInterpreter = "git"
        prefs.externalInformCoreDirectory = "/Core"
        prefs.preferencesTopLeftPosition = NSPoint(x: 120.5, y: 80.5)

        XCTAssertEqual(prefs.sourceFontFamily, "Menlo")
        XCTAssertEqual(prefs.sourceFontSize, 15.5)
        XCTAssertEqual(prefs.appFontSizeMultiplierEnum, .minus25)
        XCTAssertEqual(prefs.sourceFontStyle(for: .quotedText), .bold)
        XCTAssertEqual(prefs.sourceRelativeFontSize(for: .quotedText), .fontSizeMinus10)
        XCTAssertTrue(prefs.sourceUnderline(for: .quotedText))
        XCTAssertFalse(prefs.enableSyntaxColouring)
        XCTAssertFalse(prefs.elasticTabs)
        XCTAssertTrue(prefs.alwaysCompile)
        XCTAssertEqual(prefs.glulxInterpreter, "git")
        XCTAssertEqual(prefs.externalInformCoreDirectory, "/Core")
        XCTAssertEqual(prefs.preferencesTopLeftPosition, NSPoint(x: 120.5, y: 80.5))
    }

    /// Setting a preference to the value it has writes nothing and tells no one
    func testSettingTheSameValueAgainChangesNothing() {
        let (prefs, defaults) = makePreferences()
        prefs.tabWidth = 30.5
        let recorder = NotificationRecorder(prefs)
        let writes = defaults.writes

        prefs.tabWidth = 30.5

        XCTAssertEqual(defaults.writes, writes)
        XCTAssertEqual(recorder.names, [])
    }

    /// In a batch, nothing is written or told until it ends; then the preferences are written once, and each kind of
    /// change is told once, in the order first made
    func testABatchWritesAndTellsWhenItEnds() {
        let (prefs, defaults) = makePreferences()
        let recorder = NotificationRecorder(prefs)
        let writes = defaults.writes

        prefs.startBatchEditing()
        prefs.tabWidth = 30.5
        prefs.runBuildSh = true
        prefs.elasticTabs = false

        XCTAssertEqual(defaults.writes, writes)
        XCTAssertEqual(recorder.names, [])
        XCTAssertNil(written(defaults)["tabWidth"])

        prefs.endBatchEditing()

        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange, .IFPreferencesAdvancedDidChange])
        XCTAssertEqual(defaults.writes, writes + 1)
        XCTAssertEqual(written(defaults)["tabWidth"] as? Double, 30.5)
        XCTAssertEqual(written(defaults)["runBuildSh"] as? Bool, true)
        XCTAssertEqual(written(defaults)["elasticTabs"] as? Bool, false)
    }

    // MARK: - The app's font size

    /// Each of the app's font sizes multiplies the app's fonts by an eighth more of three quarters, from 0.625 to 1.375
    func testEachAppFontSizeHasItsMultiplier() {
        let (prefs, _) = makePreferences()
        let sizes: [IFAppFontSize] = [.minus100, .minus75, .minus50, .minus25, .normal, .plus25, .plus50, .plus75, .plus100]

        for (index, size) in sizes.enumerated() {
            prefs.appFontSizeMultiplierEnum = size

            XCTAssertEqual(prefs.appFontSizeMultiplier, 0.625 + 0.75 * CGFloat(index) / 8, "\(index)")
        }
    }

    /// A font size that isn't one of them, which only a damaged preferences file could have, is the normal size
    func testAnUnknownAppFontSizeIsTheNormalSize() {
        for size in [-1, 9, 42] {
            let (prefs, _) = makePreferences(["appFontSizeMultiplierFineEnum": size])

            XCTAssertEqual(prefs.appFontSizeMultiplier, 1.0, "\(size)")
        }
    }

    // MARK: - The author's name

    /// With no name chosen, new projects are by the user
    func testANewGameIsByTheUserUnlessANameIsChosen() {
        let (prefs, defaults) = makePreferences()
        let userName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()

        XCTAssertEqual(prefs.freshGameAuthorName, userName)

        prefs.freshGameAuthorName = "  Emily Short "
        XCTAssertEqual(prefs.freshGameAuthorName, "Emily Short")
        XCTAssertEqual(written(defaults)["newGameAuthorName"] as? String, "  Emily Short ")

        prefs.freshGameAuthorName = "   "
        XCTAssertEqual(prefs.freshGameAuthorName, userName)
    }

    /// Choosing the user's own name, in any case, goes back to following the user's name
    func testChoosingTheUsersOwnNameGoesBackToFollowingIt() {
        let (prefs, defaults) = makePreferences(["newGameAuthorName": "Emily Short"])
        let userName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()

        prefs.freshGameAuthorName = userName.uppercased()

        XCTAssertEqual(written(defaults)["newGameAuthorName"] as? String, "")
        XCTAssertEqual(prefs.freshGameAuthorName, userName)
    }

    /// ...as does choosing no name at all, which removes it
    func testChoosingNoNameRemovesIt() {
        let (prefs, defaults) = makePreferences(["newGameAuthorName": "Emily Short"])
        let userName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()

        prefs.freshGameAuthorName = nil

        XCTAssertNil(written(defaults)["newGameAuthorName"])
        XCTAssertEqual(prefs.freshGameAuthorName, userName)
    }

    // MARK: - Themes

    /// With no themes saved, the four standard ones are made and saved, and the first is the current one
    func testTheStandardThemesAreMadeWhenThereAreNone() throws {
        let (prefs, defaults) = makePreferences()

        XCTAssertEqual(prefs.themeNames, standardThemes)
        XCTAssertEqual(prefs.getCurrentTheme().themeName, "Light Mode")

        let saved = try themes(in: written(defaults)["themes"])
        XCTAssertEqual(saved.map { $0.themeName }, standardThemes)
        for theme in saved {
            XCTAssertEqual(theme.flags, 0, theme.themeName ?? "")
            XCTAssertTrue(theme.isEqualToDefault, theme.themeName ?? "")
        }

        let light = saved[0]
        XCTAssertEqual(light.sourcePaper?.colour, byteColour(255, 255, 255))
        XCTAssertEqual(light.extensionPaper?.colour, byteColour(255, 255, 228))
        XCTAssertEqual(light.option(of: .headings).colour, byteColour(230, 61, 66))
        XCTAssertEqual(light.option(of: .textSubstitutions).colour, byteColour(232, 60, 249))

        let dark = saved[1]
        XCTAssertEqual(dark.sourcePaper?.colour, byteColour(0, 0, 0))
        XCTAssertEqual(dark.extensionPaper?.colour, byteColour(66, 13, 0))
        XCTAssertEqual(dark.option(of: .mainText).colour, byteColour(255, 255, 255))

        let sevenSeas = saved[2]
        XCTAssertEqual(sevenSeas.sourcePaper?.colour, byteColour(233, 233, 255))
        XCTAssertEqual(sevenSeas.option(of: .comments).colour, byteColour(109, 167, 233))

        let traditional = saved[3]
        XCTAssertEqual(traditional.extensionPaper?.colour, NSColor(deviceRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0))
        XCTAssertEqual(traditional.option(of: .quotedText).colour, NSColor(deviceRed: 0.0, green: 0.3, blue: 0.6, alpha: 1.0))
    }

    /// Saved themes are read back, with the current one
    func testSavedThemesAreReadBack() throws {
        let (first, defaults) = makePreferences()
        let mine = first.getCurrentTheme().createDuplicateSet()
        mine.themeName = "Mine"
        mine.flags = 1
        mine.option(of: .comments).colour = byteColour(1, 2, 3)
        XCTAssertTrue(first.add(mine))
        XCTAssertTrue(first.setCurrentTheme("Mine"))

        let prefs = IFPreferences(userDefaults: defaults)

        XCTAssertEqual(prefs.themeNames, standardThemes + ["Mine"])
        XCTAssertEqual(prefs.getCurrentTheme().themeName, "Mine")
        XCTAssertEqual(prefs.sourcePaper(for: .comments).colour, byteColour(1, 2, 3))
    }

    /// Saved themes that are damaged are left out: here, one with too few options
    func testDamagedThemesAreLeftOut() throws {
        let (first, _) = makePreferences()
        let good = first.getCurrentTheme().createDuplicateSet()
        good.themeName = "Good"
        let short = first.getCurrentTheme().createDuplicateSet()
        short.themeName = "Short"
        short.options = Array(short.options.prefix(3))

        let (prefs, _) = makePreferences(["themes": try archive([short, good])])

        XCTAssertEqual(prefs.themeNames, ["Good"])
    }

    /// Saved themes that can't be read at all are replaced by the standard ones
    func testThemesThatCantBeReadAreReplaced() {
        let (prefs, _) = makePreferences(["themes": Data("Not an archive".utf8)])

        XCTAssertEqual(prefs.themeNames, standardThemes)
    }

    /// A theme is found by its name in any case, but the name is kept as it was given
    func testAThemeIsChosenByItsNameInAnyCase() {
        let (prefs, defaults) = makePreferences()
        let recorder = NotificationRecorder(prefs)
        let writes = defaults.writes

        XCTAssertTrue(prefs.setCurrentTheme("seven SEAS"))

        XCTAssertEqual(prefs.getCurrentTheme().themeName, "Seven Seas")
        XCTAssertEqual(written(defaults)["currentThemeName"] as? String, "seven SEAS")
        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange])
        XCTAssertEqual(defaults.writes, writes + 1)
    }

    /// Choosing the current theme again changes nothing, as setting any preference to its value does
    func testChoosingTheCurrentThemeAgainChangesNothing() {
        let (prefs, defaults) = makePreferences(["currentThemeName": "Seven Seas"])
        let recorder = NotificationRecorder(prefs)
        let writes = defaults.writes

        XCTAssertTrue(prefs.setCurrentTheme("Seven Seas"))

        XCTAssertEqual(recorder.names, [])
        XCTAssertEqual(defaults.writes, writes)
    }

    /// A theme that doesn't exist can't be chosen
    func testAThemeThatDoesntExistCantBeChosen() {
        let (prefs, _) = makePreferences()
        let recorder = NotificationRecorder(prefs)

        XCTAssertFalse(prefs.setCurrentTheme("Nowhere"))

        XCTAssertEqual(prefs.currentThemeName, "Light Mode")
        XCTAssertEqual(recorder.names, [])
    }

    /// If the current theme has gone, the first is the current one
    func testWithoutItsThemeTheFirstIsCurrent() {
        let (prefs, defaults) = makePreferences(["currentThemeName": "Gone"])

        XCTAssertEqual(prefs.getCurrentTheme().themeName, "Light Mode")
        XCTAssertEqual(written(defaults)["currentThemeName"] as? String, "Light Mode")
    }

    /// A theme can be added if no other has its name, in any case, and is saved
    func testAThemeIsAddedIfItsNameIsNew() throws {
        let (prefs, defaults) = makePreferences()
        let recorder = NotificationRecorder(prefs)
        let mine = prefs.getCurrentTheme().createDuplicateSet()
        mine.themeName = "Mine"
        let writes = defaults.writes

        XCTAssertTrue(prefs.add(mine))

        XCTAssertEqual(prefs.themeNames, standardThemes + ["Mine"])
        XCTAssertEqual(try themes(in: written(defaults)["themes"]).map { $0.themeName }, standardThemes + ["Mine"])
        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange])
        XCTAssertEqual(defaults.writes, writes + 1)

        let another = prefs.getCurrentTheme().createDuplicateSet()
        another.themeName = "MINE"
        XCTAssertFalse(prefs.add(another))
        XCTAssertEqual(prefs.themeNames, standardThemes + ["Mine"])
    }

    /// Only a theme that's flagged as deletable can be removed, and the rest are saved
    func testOnlyADeletableThemeCanBeRemoved() throws {
        let (prefs, defaults) = makePreferences()
        let mine = prefs.getCurrentTheme().createDuplicateSet()
        mine.themeName = "Mine"
        mine.flags = 1
        XCTAssertTrue(prefs.add(mine))

        XCTAssertFalse(prefs.removeTheme("Dark Mode"))
        XCTAssertFalse(prefs.removeTheme("Nowhere"))
        XCTAssertEqual(prefs.themeNames, standardThemes + ["Mine"])

        let recorder = NotificationRecorder(prefs)
        let writes = defaults.writes
        XCTAssertTrue(prefs.removeTheme("mine"))

        XCTAssertEqual(prefs.themeNames, standardThemes)
        XCTAssertEqual(try themes(in: written(defaults)["themes"]).map { $0.themeName }, standardThemes)
        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange])
        XCTAssertEqual(defaults.writes, writes + 1)
    }

    /// Dark mode switches between the Light Mode and Dark Mode themes, but leaves any other alone
    func testDarkModeSwitchesOnlyBetweenLightAndDark() {
        let (prefs, _) = makePreferences()

        prefs.setDarkMode(true)
        XCTAssertEqual(prefs.currentThemeName, "Dark Mode")
        prefs.setDarkMode(true)
        XCTAssertEqual(prefs.currentThemeName, "Dark Mode")
        prefs.setDarkMode(false)
        XCTAssertEqual(prefs.currentThemeName, "Light Mode")

        XCTAssertTrue(prefs.setCurrentTheme("Seven Seas"))
        prefs.setDarkMode(true)
        XCTAssertEqual(prefs.currentThemeName, "Seven Seas")
    }

    /// The paper colours are the current theme's, and setting them saves a copy in it
    func testThePaperColoursAreTheCurrentThemes() throws {
        let (prefs, defaults) = makePreferences()
        XCTAssertTrue(prefs.setCurrentTheme("Dark Mode"))
        XCTAssertEqual(prefs.sourcePaper.colour, byteColour(0, 0, 0))
        XCTAssertEqual(prefs.extensionPaper.colour, byteColour(66, 13, 0))

        let recorder = NotificationRecorder(prefs)
        let paper = IFSyntaxColouringOption(colour: byteColour(10, 20, 30))
        prefs.sourcePaper = paper
        prefs.extensionPaper = paper

        XCTAssertEqual(prefs.getCurrentTheme().sourcePaper?.colour, byteColour(10, 20, 30))
        XCTAssertEqual(prefs.getCurrentTheme().extensionPaper?.colour, byteColour(10, 20, 30))
        XCTAssertNotIdentical(prefs.getCurrentTheme().sourcePaper, paper)
        XCTAssertNotIdentical(prefs.getCurrentTheme().extensionPaper, paper)
        XCTAssertEqual(try themes(in: written(defaults)["themes"])[1].sourcePaper?.colour, byteColour(10, 20, 30))
        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange, .IFPreferencesEditingDidChange])
    }

    /// The colours of the kinds of text are the current theme's, and setting one saves it
    func testTheColoursOfTextAreTheCurrentThemes() throws {
        let (prefs, defaults) = makePreferences()
        XCTAssertIdentical(prefs.sourcePaper(for: .quotedText), prefs.getCurrentTheme().option(of: .quotedText))

        let recorder = NotificationRecorder(prefs)
        prefs.setSourceColour(byteColour(10, 20, 30), for: .quotedText)

        XCTAssertEqual(prefs.sourcePaper(for: .quotedText).colour, byteColour(10, 20, 30))
        XCTAssertEqual(try themes(in: written(defaults)["themes"])[0].option(of: .quotedText).colour, byteColour(10, 20, 30))
        XCTAssertEqual(recorder.names, [.IFPreferencesEditingDidChange])
    }

    // MARK: - Styles

    /// There's a style for each of the 256 syntax styles
    func testThereIsAStyleForEachSyntaxStyle() {
        let (prefs, _) = makePreferences()

        XCTAssertEqual(prefs.styles.count, 256)
    }

    /// Inform 7's styles take the current theme's colours, and the fonts and underlining of their kinds of text
    func testInform7StylesFollowTheThemeAndFonts() throws {
        let (prefs, _) = makePreferences()
        prefs.sourceFontFamily = "Helvetica"
        prefs.sourceFontSize = 20
        prefs.setSourceFontStyle(.bold, for: .headings)
        prefs.setSourceFontStyle(.italic, for: .comments)
        prefs.setSourceRelativeFontSize(.fontSizeMinus30, for: .comments)
        XCTAssertTrue(prefs.setCurrentTheme("Dark Mode"))

        let kinds: [(IFSyntaxStyle, IFSyntaxHighlightingOptionType)] = [
            (.title, .headings), (.heading, .headings), (.naturalInform, .mainText), (.comment, .comments),
            (.gameText, .quotedText), (.substitution, .textSubstitutions),
        ]
        let theme = prefs.getCurrentTheme()
        for (syntaxStyle, type) in kinds {
            let attributes = style(prefs, syntaxStyle)
            XCTAssertEqual(attributes[.foregroundColor] as? NSColor, theme.option(of: type).colour, "\(syntaxStyle.rawValue)")
            XCTAssertEqual((attributes[.font] as? NSFont)?.familyName, "Helvetica", "\(syntaxStyle.rawValue)")
            XCTAssertEqual(attributes[.underlineStyle] as? Int,
                           type == .headings ? NSUnderlineStyle.single.rawValue : 0, "\(syntaxStyle.rawValue)")
        }

        let heading = try XCTUnwrap(style(prefs, .heading)[.font] as? NSFont)
        XCTAssertEqual(heading.pointSize, 20 * CGFloat(Float(1.1)))
        XCTAssertTrue(NSFontManager.shared.traits(of: heading).contains(.boldFontMask))

        let comment = try XCTUnwrap(style(prefs, .comment)[.font] as? NSFont)
        XCTAssertEqual(comment.pointSize, 20 * CGFloat(Float(0.7)))
        XCTAssertTrue(NSFontManager.shared.traits(of: comment).contains(.italicFontMask))

        let mainText = try XCTUnwrap(style(prefs, .naturalInform)[.font] as? NSFont)
        XCTAssertEqual(mainText.pointSize, 20)
        XCTAssertFalse(NSFontManager.shared.traits(of: mainText).contains(.boldFontMask))
    }

    /// How far right the top of an "l" drawn in a font is from its bottom, in pixels: 0 for an upright font
    private func slant(of font: NSFont) throws -> Int {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                                 bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        NSAttributedString(string: "l", attributes: [.font: font, .foregroundColor: NSColor.black])
            .draw(at: NSPoint(x: 40, y: 10))
        NSGraphicsContext.restoreGraphicsState()

        // The leftmost ink in each row with ink, from the top
        var edges: [(row: Int, x: Int)] = []
        for row in 0..<100 {
            if let x = (0..<100).first(where: { (rep.colorAt(x: $0, y: row)?.brightnessComponent ?? 1) < 0.5 }) {
                edges.append((row, x))
            }
        }
        let top = try XCTUnwrap(edges.first?.row)
        let bottom = try XCTUnwrap(edges.last?.row)
        let quarter = (bottom - top) / 4
        let topEdge = try XCTUnwrap(edges.filter { $0.row <= top + quarter }.map(\.x).min())
        let bottomEdge = try XCTUnwrap(edges.filter { $0.row >= bottom - quarter }.map(\.x).min())
        return topEdge - bottomEdge
    }

    /// Text in italics is slanted though its font has no italic face, as Lucida Grande, the default, hasn't, and
    /// keeps its font's family and size
    func testItalicsInAFontWithNoItalicFace() throws {
        let (prefs, _) = makePreferences()
        prefs.sourceFontFamily = "Lucida Grande"
        prefs.sourceFontSize = 40
        prefs.setSourceFontStyle(.regular, for: .mainText)
        prefs.setSourceFontStyle(.italic, for: .comments)
        prefs.setSourceRelativeFontSize(.fontSizeNormal, for: .comments)
        prefs.setSourceFontStyle(.boldItalic, for: .headings)

        let mainText = try XCTUnwrap(style(prefs, .naturalInform)[.font] as? NSFont)
        let comment = try XCTUnwrap(style(prefs, .comment)[.font] as? NSFont)
        let heading = try XCTUnwrap(style(prefs, .heading)[.font] as? NSFont)
        XCTAssertEqual(try slant(of: mainText), 0)
        XCTAssertGreaterThan(try slant(of: comment), 0)
        XCTAssertGreaterThan(try slant(of: heading), 0)

        XCTAssertEqual(comment.familyName, "Lucida Grande")
        XCTAssertEqual(comment.pointSize, 40)
        XCTAssertEqual(heading.familyName, "Lucida Grande")
        XCTAssertTrue(NSFontManager.shared.traits(of: heading).contains(.boldFontMask))
    }

    /// Inform 6's styles have colours of their own, and the main text's font
    func testInform6StylesHaveTheirOwnColours() throws {
        let (prefs, _) = makePreferences()
        let colours: [(IFSyntaxStyle, NSColor)] = [
            ([], NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)),
            (.string, NSColor(deviceRed: 0.53, green: 3 * 0.08, blue: 3 * 0.08, alpha: 1.0)),
            (.directive, NSColor(deviceRed: 3 * 0.20, green: 3 * 0.08, blue: 0.53, alpha: 1.0)),
            (.property, NSColor(deviceRed: 3 * 0.08, green: 3 * 0.08, blue: 0.53, alpha: 1.0)),
            (.function, NSColor(deviceRed: 3 * 0.08, green: 3 * 0.53, blue: 0.53, alpha: 1.0)),
            (.code, NSColor(deviceRed: 0.46, green: 3 * 0.06, blue: 0.31, alpha: 1.0)),
            (.assembly, NSColor(deviceRed: 0.46, green: 0.31, blue: 0.31, alpha: 1.0)),
            (.codeAlpha, NSColor(deviceRed: 0.4, green: 0.4, blue: 0.3, alpha: 1.0)),
            (.escapeCharacter, NSColor(deviceRed: 0.4, green: 0.4, blue: 0.3, alpha: 1.0)),
        ]
        for (syntaxStyle, colour) in colours {
            XCTAssertEqual(style(prefs, syntaxStyle)[.foregroundColor] as? NSColor, colour, "\(syntaxStyle.rawValue)")
            XCTAssertEqual(style(prefs, syntaxStyle)[.underlineStyle] as? Int, 0, "\(syntaxStyle.rawValue)")
        }

        let mainText = style(prefs, .naturalInform)[.font] as? NSFont
        let quotedText = style(prefs, .gameText)[.font] as? NSFont
        XCTAssertEqual(style(prefs, [])[.font] as? NSFont, mainText)
        XCTAssertEqual(style(prefs, .property)[.font] as? NSFont, quotedText)
        XCTAssertEqual(style(prefs, .monospace)[.foregroundColor] as? NSColor, NSColor.black)
    }

    /// Without colouring, styles have no colours; without highlighting, no fonts or underlining
    func testColouringAndHighlightingCanEachBeTurnedOff() {
        let (prefs, _) = makePreferences()

        prefs.enableSyntaxColouring = false
        XCTAssertNil(style(prefs, .heading)[.foregroundColor])
        XCTAssertNotNil(style(prefs, .heading)[.font])
        XCTAssertNotNil(style(prefs, .heading)[.underlineStyle])

        prefs.enableSyntaxHighlighting = false
        XCTAssertTrue(style(prefs, .heading).isEmpty)

        prefs.enableSyntaxColouring = true
        XCTAssertNotNil(style(prefs, .heading)[.foregroundColor])
        XCTAssertNil(style(prefs, .heading)[.font])
        XCTAssertNil(style(prefs, .heading)[.underlineStyle])
    }

    /// The styles are a copy, which a later change doesn't alter
    func testTheStylesAreACopy() {
        let (prefs, _) = makePreferences()
        let styles = prefs.styles

        prefs.enableSyntaxColouring = false

        XCTAssertNotNil(styles[Int(IFSyntaxStyle.heading.rawValue)][NSAttributedString.Key.foregroundColor])
        XCTAssertNil(style(prefs, .heading)[.foregroundColor])
    }

    // MARK: - The test host's preferences

    /// The test host started without its home folder, so it can't read or write the user's preferences. The scheme's
    /// Test action gives it a home folder (CFFIXED_USER_HOME) and removes that folder before each run, and while the
    /// folder doesn't exist CFPreferences cuts the app off from the user's preferences (the log says the "home directory
    /// is inaccessible"). The app's own preferences then start empty and its writes stay in memory.
    func testTheTestHostStartedWithoutItsHomeFolder() throws {
        let home = NSHomeDirectory()
        XCTAssertEqual((home as NSString).lastPathComponent, "TestHome", "Not the tests' own home folder")

        // Tests make the folder as they run, which is fine once the app has started without it
        if let made = try? FileManager.default.attributesOfItem(atPath: home)[.creationDate] as? Date {
            let started = try XCTUnwrap(NSRunningApplication.current.launchDate)
            XCTAssertGreaterThan(made, started, "The tests' home folder was there when the test host started")
        }
    }
}
