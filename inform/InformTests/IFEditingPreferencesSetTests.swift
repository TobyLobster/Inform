//
//  IFEditingPreferencesSetTests.swift
//  InformTests
//

import XCTest

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
}
