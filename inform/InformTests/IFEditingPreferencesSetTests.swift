//
//  IFEditingPreferencesSetTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any] = [:]

    init() {
        super.init(suiteName: "IFEditingPreferencesSetTests.never-written")!
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

final class IFEditingPreferencesSetTests: XCTestCase {

    private let types: [IFSyntaxHighlightingOptionType] = [.headings, .mainText, .comments, .quotedText, .textSubstitutions]

    /// A set with every setting changed from its default
    private func makeChangedSet() -> IFEditingPreferencesSet {
        let set = IFEditingPreferencesSet()
        set.fontFamily = "Menlo"
        set.fontSize = 15
        set.enableSyntaxHighlighting = false
        set.tabWidth = 40
        set.autoIndentAfterNewline = false
        set.autoSpaceTableColumns = false
        set.autoNumberSections = false
        for type in types {
            let option = set.option(of: type)
            option.fontStyle = .boldItalic
            option.underline = !option.underline
            option.relativeFontSize = .fontSizeMinus20
        }
        return set
    }

    /// A new option is regular, not underlined, and the normal size
    func testANewOptionIsRegularNormalSizeAndNotUnderlined() {
        let option = IFSyntaxHighlightingOption()

        XCTAssertEqual(option.fontStyle, .regular)
        XCTAssertFalse(option.underline)
        XCTAssertEqual(option.relativeFontSize, .fontSizeNormal)
    }

    /// A new set has the default settings: the defaults of the editing preferences
    func testANewSetHasTheDefaultSettings() {
        let set = IFEditingPreferencesSet()

        XCTAssertEqual(set.fontFamily, "Lucida Grande")
        XCTAssertEqual(set.fontSize, 12)
        XCTAssertTrue(set.enableSyntaxHighlighting)
        XCTAssertEqual(set.tabWidth, 24)
        XCTAssertTrue(set.autoIndentAfterNewline)
        XCTAssertTrue(set.autoSpaceTableColumns)
        XCTAssertTrue(set.autoNumberSections)
    }

    /// ...with an option of each type: headings are underlined and larger, and the rest are plain
    func testANewSetHasAnOptionOfEachType() {
        let set = IFEditingPreferencesSet()

        XCTAssertEqual(set.options.count, Int(IFSyntaxHighlightingOptionType.count.rawValue))

        let headings = set.option(of: .headings)
        XCTAssertEqual(headings.fontStyle, .regular)
        XCTAssertTrue(headings.underline)
        XCTAssertEqual(headings.relativeFontSize, .fontSizePlus10)

        for type in types where type != .headings {
            let option = set.option(of: type)
            XCTAssertEqual(option.fontStyle, .regular, "\(type.rawValue)")
            XCTAssertFalse(option.underline, "\(type.rawValue)")
            XCTAssertEqual(option.relativeFontSize, .fontSizeNormal, "\(type.rawValue)")
        }
    }

    /// Each type of option is the one at its place in the options
    func testEachTypeOfOptionIsTheOneAtItsPlace() {
        let set = IFEditingPreferencesSet()

        for (index, type) in types.enumerated() {
            XCTAssertIdentical(set.option(of: type), set.options[index] as AnyObject)
        }
    }

    /// Resetting a set puts back every default, in the same options
    func testResettingPutsBackEveryDefault() {
        let set = makeChangedSet()
        let options = types.map { set.option(of: $0) }

        set.resetSettings()

        XCTAssertTrue(set.isEqual(toPreferenceSet: IFEditingPreferencesSet()))
        XCTAssertEqual(set.fontFamily, "Lucida Grande")
        XCTAssertEqual(set.option(of: .headings).relativeFontSize, .fontSizePlus10)
        for (index, type) in types.enumerated() {
            XCTAssertIdentical(set.option(of: type), options[index])
        }
    }

    /// Two sets with the same settings are equal, which turns the Restore button off
    func testSetsWithTheSameSettingsAreEqual() {
        XCTAssertTrue(IFEditingPreferencesSet().isEqual(toPreferenceSet: IFEditingPreferencesSet()))
        XCTAssertTrue(makeChangedSet().isEqual(toPreferenceSet: makeChangedSet()))
    }

    /// Font families are compared by name
    func testFontFamiliesAreComparedByName() {
        let set = IFEditingPreferencesSet()
        set.fontFamily = NSMutableString(string: "Lucida Grande") as String

        XCTAssertTrue(set.isEqual(toPreferenceSet: IFEditingPreferencesSet()))
    }

    /// Any one setting that differs makes two sets unequal, which turns the Restore button on
    func testAnyOneDifferentSettingMakesSetsUnequal() {
        var changes: [(String, (IFEditingPreferencesSet) -> Void)] = [
            ("font family", { $0.fontFamily = "Menlo" }),
            ("font size", { $0.fontSize = 13 }),
            ("syntax highlighting", { $0.enableSyntaxHighlighting = false }),
            ("tab width", { $0.tabWidth = 24.5 }),
            ("indenting", { $0.autoIndentAfterNewline = false }),
            ("table columns", { $0.autoSpaceTableColumns = false }),
            ("numbering", { $0.autoNumberSections = false }),
        ]
        for type in types {
            changes.append(("style \(type.rawValue)", { $0.option(of: type).fontStyle = .italic }))
            changes.append(("underline \(type.rawValue)", { $0.option(of: type).underline = !$0.option(of: type).underline }))
            changes.append(("size \(type.rawValue)", { $0.option(of: type).relativeFontSize = .fontSizePlus30 }))
        }

        for (name, change) in changes {
            let set = IFEditingPreferencesSet()
            change(set)

            XCTAssertFalse(set.isEqual(toPreferenceSet: IFEditingPreferencesSet()), name)
            XCTAssertFalse(IFEditingPreferencesSet().isEqual(toPreferenceSet: set), name)
        }
    }

    /// A set is copied to each of the editing preferences given
    func testASetIsCopiedToThePreferences() {
        let preferences = IFPreferences(userDefaults: MemoryDefaults())

        makeChangedSet().update(preferences)

        XCTAssertEqual(preferences.sourceFontFamily, "Menlo")
        XCTAssertEqual(preferences.sourceFontSize, 15)
        XCTAssertFalse(preferences.enableSyntaxHighlighting)
        XCTAssertEqual(preferences.tabWidth, 40)
        XCTAssertFalse(preferences.indentAfterNewline)
        XCTAssertFalse(preferences.elasticTabs)
        XCTAssertFalse(preferences.autoNumberSections)
        for type in types {
            XCTAssertEqual(preferences.sourceFontStyle(for: type), .boldItalic, "\(type.rawValue)")
            XCTAssertEqual(preferences.sourceUnderline(for: type), type != .headings, "\(type.rawValue)")
            XCTAssertEqual(preferences.sourceRelativeFontSize(for: type), .fontSizeMinus20, "\(type.rawValue)")
        }
    }

    /// ...and the editing preferences given are copied to a set
    func testASetIsCopiedFromThePreferences() {
        let preferences = IFPreferences(userDefaults: MemoryDefaults())
        let set = makeChangedSet()

        set.updateSet(from: preferences)
        XCTAssertTrue(set.isEqual(toPreferenceSet: IFEditingPreferencesSet()))

        makeChangedSet().update(preferences)
        set.updateSet(from: preferences)
        XCTAssertTrue(set.isEqual(toPreferenceSet: makeChangedSet()))
    }
}
