//
//  IFColourThemeTests.swift
//  InformTests
//

import XCTest

/// Archived under IFSyntaxColouringOption's name with only the colours given, to make a damaged option
@objc(IFColourThemeTestsPartialOption)
private final class PartialOption: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    private let colours: [String: NSColor]

    init(_ colours: [String: NSColor]) {
        self.colours = colours
    }

    func encode(with coder: NSCoder) {
        for (key, colour) in colours {
            coder.encode(colour, forKey: key)
        }
    }

    init?(coder: NSCoder) {
        return nil
    }
}

/// Archived under IFColourTheme's name with only the values and options given, to make a damaged theme
@objc(IFColourThemeTestsPartialTheme)
private final class PartialTheme: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    private let values: [String: Any]
    private let options: [NSObject]
    private let optionsCount: Int32

    init(_ values: [String: Any], options: [NSObject], optionsCount: Int32? = nil) {
        self.values = values
        self.options = options
        self.optionsCount = optionsCount ?? Int32(options.count)
    }

    func encode(with coder: NSCoder) {
        for (key, value) in values {
            coder.encode(value, forKey: key)
        }
        coder.encodeCInt(optionsCount, forKey: "optionsCount")
        for (index, option) in options.enumerated() {
            coder.encode(option, forKey: "option\(index)")
        }
    }

    init?(coder: NSCoder) {
        return nil
    }
}

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFColourThemeTests.never-written")!
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

final class IFColourThemeTests: XCTestCase {

    private let red = NSColor(deviceRed: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
    private let green = NSColor(deviceRed: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
    private let blue = NSColor(deviceRed: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)

    private let types: [IFSyntaxHighlightingOptionType] = [.headings, .mainText, .comments, .quotedText, .textSubstitutions]

    /// A theme with paper colours, as the preferences make them
    private func makeTheme() -> IFColourTheme {
        let theme = IFColourTheme()
        theme.themeName = "Mine"
        theme.sourcePaper = IFSyntaxColouringOption(colour: red)
        theme.extensionPaper = IFSyntaxColouringOption(colour: green)
        return theme
    }

    /// The values a theme is archived with, all there
    private func themeValues() -> [String: Any] {
        return ["themeName": "Damaged",
                "flags": NSNumber(value: 1),
                "sourcePaper": IFSyntaxColouringOption(colour: red),
                "extensionPaper": IFSyntaxColouringOption(colour: green)]
    }

    private func themeOptions() -> [NSObject] {
        return types.map { _ in IFSyntaxColouringOption(colour: blue) }
    }

    private func archive(_ object: Any) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.setClassName("IFColourTheme", for: PartialTheme.self)
        archiver.setClassName("IFSyntaxColouringOption", for: PartialOption.self)
        archiver.encode(object, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private func unarchive(_ data: Data) throws -> IFColourTheme {
        return try XCTUnwrap(try NSKeyedUnarchiver.unarchivedObject(ofClass: IFColourTheme.self, from: data))
    }

    /// A new theme has an option of each type, in black, and no name or paper colours yet
    func testANewThemeHasAnOptionOfEachTypeInBlack() {
        let theme = IFColourTheme()

        XCTAssertEqual(theme.options.count, Int(IFSyntaxHighlightingOptionType.count.rawValue))
        for type in types {
            XCTAssertEqual(theme.option(of: type).colour, NSColor.black)
            XCTAssertEqual(theme.option(of: type).defaultColour, NSColor.black)
        }
        XCTAssertEqual(theme.flags, 0)
        XCTAssertNil(theme.themeName)
        XCTAssertNil(theme.sourcePaper)
        XCTAssertNil(theme.extensionPaper)
    }

    /// Each type of option is the one at its place in the options
    func testEachTypeOfOptionIsTheOneAtItsPlace() {
        let theme = IFColourTheme()

        for (index, type) in types.enumerated() {
            XCTAssertIdentical(theme.option(of: type), theme.options[index] as AnyObject)
        }
    }

    /// Resetting a theme puts back every colour's default
    func testResettingPutsBackEveryDefaultColour() {
        let theme = makeTheme()
        theme.sourcePaper?.colour = blue
        theme.extensionPaper?.colour = blue
        for type in types {
            theme.option(of: type).colour = green
        }

        theme.resetSettings()

        XCTAssertEqual(theme.sourcePaper?.colour, red)
        XCTAssertEqual(theme.extensionPaper?.colour, green)
        for type in types {
            XCTAssertEqual(theme.option(of: type).colour, NSColor.black)
        }
    }

    /// A theme is the default only while every colour is, which turns the Restore button off
    func testAThemeIsTheDefaultOnlyWhileEveryColourIs() {
        let theme = makeTheme()
        XCTAssertTrue(theme.isEqualToDefault)

        theme.option(of: .quotedText).colour = blue
        XCTAssertFalse(theme.isEqualToDefault)

        theme.resetSettings()
        XCTAssertTrue(theme.isEqualToDefault)

        theme.extensionPaper?.colour = blue
        XCTAssertFalse(theme.isEqualToDefault)
    }

    /// Colours are compared as generic RGB, so the same colour in another colour space is still the default
    func testColoursAreComparedAsGenericRGB() throws {
        let theme = makeTheme()
        theme.sourcePaper?.colour = try XCTUnwrap(red.usingColorSpace(.genericRGB))
        XCTAssertNotEqual(theme.sourcePaper?.colour, red)

        XCTAssertTrue(theme.isEqualToDefault)
    }

    /// ...so a theme without paper colours, which have nothing to compare, is never the default
    func testAThemeWithoutPaperColoursIsNeverTheDefault() {
        let theme = IFColourTheme()

        XCTAssertFalse(theme.isEqualToDefault)
    }

    /// A duplicate has the same name, flags and colours, and its own options, as a new theme made from the current one does
    func testADuplicateHasTheSameColoursAndItsOwnOptions() {
        let theme = makeTheme()
        theme.flags = 1
        theme.sourcePaper?.colour = blue
        theme.option(of: .comments).colour = green

        let duplicate = theme.createDuplicateSet()

        XCTAssertEqual(duplicate.themeName, "Mine")
        XCTAssertEqual(duplicate.flags, 1)
        XCTAssertEqual(duplicate.sourcePaper?.colour, blue)
        XCTAssertEqual(duplicate.sourcePaper?.defaultColour, red)
        XCTAssertEqual(duplicate.extensionPaper?.colour, green)
        XCTAssertEqual(duplicate.options.count, theme.options.count)
        XCTAssertEqual(duplicate.option(of: .comments).colour, green)
        XCTAssertEqual(duplicate.option(of: .comments).defaultColour, NSColor.black)

        XCTAssertNotIdentical(duplicate.sourcePaper, theme.sourcePaper)
        XCTAssertNotIdentical(duplicate.extensionPaper, theme.extensionPaper)
        for type in types {
            XCTAssertNotIdentical(duplicate.option(of: type), theme.option(of: type))
        }
        duplicate.option(of: .comments).colour = red
        XCTAssertEqual(theme.option(of: .comments).colour, green)
    }

    /// Preferences kept in memory, whose current theme is the one named
    private func makePreferences(currentTheme: String) -> IFPreferences {
        return IFPreferences(userDefaults: MemoryDefaults([IFPreferencesDefault: ["currentThemeName": currentTheme]]))
    }

    /// The Colour preferences copy the current theme from the preferences, default colours and flags too
    func testAThemeIsUpdatedFromThePreferencesCurrentTheme() {
        let preferences = makePreferences(currentTheme: "Dark Mode")
        preferences.setSourceColour(red, for: .headings)
        let current = preferences.getCurrentTheme()
        let theme = makeTheme()

        theme.updateSet(from: preferences)

        XCTAssertEqual(theme.themeName, "Mine")
        XCTAssertEqual(theme.flags, current.flags)
        XCTAssertEqual(theme.sourcePaper?.colour, current.sourcePaper?.colour)
        XCTAssertEqual(theme.extensionPaper?.colour, current.extensionPaper?.colour)
        XCTAssertNotIdentical(theme.sourcePaper, current.sourcePaper)
        for type in types {
            XCTAssertEqual(theme.option(of: type).colour, current.option(of: type).colour)
            XCTAssertEqual(theme.option(of: type).defaultColour, current.option(of: type).defaultColour)
        }
        XCTAssertEqual(theme.option(of: .headings).colour, red)
        XCTAssertNotEqual(theme.option(of: .headings).defaultColour, red)
    }

    /// ...and copy their changes back to it, with whether to colour syntax
    func testAThemeUpdatesThePreferencesCurrentTheme() {
        let preferences = makePreferences(currentTheme: "Seven Seas")
        let theme = makeTheme()
        theme.option(of: .comments).colour = blue

        theme.update(preferences, fromSetWithEnable: false)

        XCTAssertEqual(preferences.currentThemeName, "Seven Seas")
        XCTAssertEqual(preferences.sourcePaper.colour, red)
        XCTAssertEqual(preferences.extensionPaper.colour, green)
        XCTAssertEqual(preferences.sourcePaper(for: .comments).colour, blue)
        XCTAssertEqual(preferences.sourcePaper(for: .headings).colour, NSColor.black)
        XCTAssertFalse(preferences.enableSyntaxColouring)
        XCTAssertNotEqual(preferences.getCurrentTheme().themeName, "Mine")

        XCTAssertTrue(preferences.setCurrentTheme("Light Mode"))
        XCTAssertNotEqual(preferences.sourcePaper(for: .comments).colour, blue)
    }

    /// Themes are kept in the preferences as a secure archive
    func testAThemeIsArchivedWithEverything() throws {
        let theme = makeTheme()
        theme.flags = 1
        theme.sourcePaper?.colour = blue
        theme.option(of: .headings).colour = red
        theme.option(of: .textSubstitutions).defaultColour = green

        let read = try unarchive(archive(theme))

        XCTAssertEqual(read.themeName, "Mine")
        XCTAssertEqual(read.flags, 1)
        XCTAssertEqual(read.sourcePaper?.colour, blue)
        XCTAssertEqual(read.sourcePaper?.defaultColour, red)
        XCTAssertEqual(read.extensionPaper?.colour, green)
        XCTAssertEqual(read.options.count, theme.options.count)
        XCTAssertEqual(read.option(of: .headings).colour, red)
        XCTAssertEqual(read.option(of: .textSubstitutions).defaultColour, green)
        XCTAssertTrue(IFColourTheme.supportsSecureCoding)
    }

    /// An archived theme without a name or a paper colour reads without them, and the preferences leave it out
    func testAnArchivedThemeWithoutANameOrPaperReadsWithoutThem() throws {
        var values = themeValues()
        values["themeName"] = nil
        values["sourcePaper"] = nil

        let read = try unarchive(archive(PartialTheme(values, options: themeOptions())))

        XCTAssertNil(read.themeName)
        XCTAssertNil(read.sourcePaper)
        XCTAssertNotNil(read.extensionPaper)
        XCTAssertEqual(read.options.count, types.count)
    }

    /// ...as it does one without flags
    func testAnArchivedThemeWithoutFlagsReadsWithout() throws {
        var values = themeValues()
        values["flags"] = nil

        let read = try unarchive(archive(PartialTheme(values, options: themeOptions())))

        XCTAssertNil(read.flags)
        XCTAssertEqual(read.themeName, "Damaged")
    }

    /// An archived theme with fewer options reads with fewer, and the preferences leave it out
    func testAnArchivedThemeWithFewerOptionsReadsWithFewer() throws {
        let read = try unarchive(archive(PartialTheme(themeValues(), options: Array(themeOptions().prefix(3)))))

        XCTAssertEqual(read.options.count, 3)
    }

    /// An archived theme with a damaged count of options, less than none, reads with none
    func testAnArchivedThemeWithANegativeCountOfOptionsReadsWithNone() throws {
        let read = try unarchive(archive(PartialTheme(themeValues(), options: themeOptions(), optionsCount: -1)))

        XCTAssertEqual(read.options.count, 0)
    }

    /// An archived theme with an option it can't read reads with no options, so that the preferences leave out just
    /// that theme, as they leave out one with no paper colour. (Reading as nothing, as the option does, would lose
    /// the themes archived with it too.)
    func testAnArchivedThemeWithAnOptionItCantReadReadsWithNone() throws {
        var options = themeOptions()
        options[2] = PartialOption(["defaultColour": red])

        let read = try unarchive(archive(PartialTheme(themeValues(), options: options)))

        XCTAssertEqual(read.options.count, 0)
    }

    /// ...and the themes archived with it are still read
    func testThemesArchivedWithOneWithAnOptionItCantReadAreStillRead() throws {
        var options = themeOptions()
        options[2] = PartialOption(["colour": red])
        let data = archive([makeTheme(), PartialTheme(themeValues(), options: options)])

        let read = try XCTUnwrap(try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, IFColourTheme.self],
                                                                         from: data) as? [IFColourTheme])

        XCTAssertEqual(read.count, 2)
        XCTAssertEqual(read.first?.themeName, "Mine")
        XCTAssertEqual(read.first?.options.count, types.count)
        XCTAssertEqual(read.last?.options.count, 0)
    }
}
