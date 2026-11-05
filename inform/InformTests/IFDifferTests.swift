//
//  IFDifferTests.swift
//  InformTests
//

import XCTest

final class IFDifferTests: XCTestCase {

    /// The start of a transcript, with an old-style banner from the given serial number and Inform 6 version.
    private func transcript(serial: String, i6: String, room: String = "Bedroom") -> String {
        return "Story\nAn Interactive Fiction by Jane Doe\n"
            + "Release 1 / Serial number \(serial) / Inform 7 build 6M62 (I6/v\(i6) lib 6/12N) SD\n\n"
            + "\(room)\nIt's dark.\n\n>"
    }

    /// Banners from different builds count as the same.
    func testBannersFromDifferentBuildsMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "141106", i6: "6.33"),
                                        actual: transcript(serial: "150101", i6: "6.34")))
        XCTAssertEqual(differ.differences.count, 0)
    }

    /// The text either side of the banner is still compared.
    func testTextAroundTheBannerIsCompared() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal(transcript(serial: "141106", i6: "6.33"),
                                       actual: transcript(serial: "150101", i6: "6.34", room: "Kitchen")))
        XCTAssertTrue(differ.diffIdeal("Hello\n" + transcript(serial: "141106", i6: "6.33"),
                                       actual: "Goodbye\n" + transcript(serial: "150101", i6: "6.34")))
    }

    /// The start of a transcript with the banner Inform 10 prints, as in "Inform 7 v10.2.0 / D".
    private func transcript(serial: String, version: String, room: String = "Bedroom") -> String {
        return "Story\nAn Interactive Fiction by Jane Doe\n"
            + "Release 1 / Serial number \(serial) / Inform 7 v\(version) / D\n\n"
            + "\(room)\nIt's dark.\n\n>"
    }

    /// Inform 10's banners from different days and builds count as the same.
    func testInform10BannersFromDifferentBuildsMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "261104", version: "10.2.0"),
                                        actual: transcript(serial: "261105", version: "10.2.0")))
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "221105", version: "10.1.2"),
                                        actual: transcript(serial: "261105", version: "10.2.0-beta+6Y13")))
        XCTAssertTrue(differ.diffIdeal(transcript(serial: "261104", version: "10.2.0"),
                                       actual: transcript(serial: "261105", version: "10.2.0", room: "Kitchen")))
    }

    /// A transcript blessed with an older Inform still matches one from Inform 10.
    func testOldAndInform10BannersMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "151220", i6: "6.33"),
                                        actual: transcript(serial: "261104", version: "10.2.0")))
    }

    /// Without a banner on both sides, a different serial number is a difference.
    func testSerialNumbersDifferWithoutABanner() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal("Serial number 141106", actual: "Serial number 150101"))
    }

    /// Around a banner, the edits keep the actual transcript's banner.
    func testEditsKeepTheActualBanner() {
        XCTAssertEqual(edits(transcript(serial: "141106", i6: "6.33"),
                             transcript(serial: "150101", i6: "6.34", room: "Kitchen")),
                       transcript(serial: "150101", i6: "6.34", room: "<delete>Bedroom</delete><insert>Kitchen</insert>"))
    }

    // MARK: - The edits

    /// The differ's edits as text: deleted text in <delete>, inserted text in <insert>, and kept text as it is
    private func render(_ differ: IFDiffer) -> String {
        let ideal = (differ.ideal ?? "") as NSString
        let actual = (differ.actual ?? "") as NSString
        var result = ""
        for case let edit as IFDiffEdit in differ.differences {
            switch edit.formOfEdit {
            case .DELETE_EDIT:          result += "<delete>" + ideal.substring(with: edit.fragment) + "</delete>"
            case .PRESERVE_EDIT:        result += ideal.substring(with: edit.fragment)
            case .PRESERVE_ACTUAL_EDIT: result += actual.substring(with: edit.fragment)
            case .INSERT_EDIT:          result += "<insert>" + actual.substring(with: edit.fragment) + "</insert>"
            @unknown default:           XCTFail("Unknown edit \(edit.formOfEdit)")
            }
        }
        return result
    }

    private func edits(_ ideal: String?, _ actual: String?) -> String {
        let differ = IFDiffer()
        differ.diffIdeal(ideal, actual: actual)
        return render(differ)
    }

    func testTheSameTextHasNoEdits() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal("You are in the kitchen.", actual: "You are in the kitchen."))
        XCTAssertEqual(differ.differences.count, 0)
        XCTAssertEqual(differ.ideal, "You are in the kitchen.")
        XCTAssertEqual(differ.actual, "You are in the kitchen.")
    }

    /// No text is the same as an empty one.
    func testNoText() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(nil, actual: ""))
        XCTAssertEqual(differ.ideal, "")
        XCTAssertEqual(differ.actual, "")
        XCTAssertEqual(edits(nil, "Hello"), "<insert>Hello</insert>")
        XCTAssertEqual(edits("Hello", nil), "<delete>Hello</delete>")
    }

    /// The common start and end are kept, back to whole words.
    func testKeepsTheCommonStartAndEnd() {
        XCTAssertEqual(edits("You are in the kitchen.", "You are in the bedroom."),
                       "You are in the <delete>kitchen</delete><insert>bedroom</insert>.")
    }

    /// Words are changed whole, not letter by letter.
    func testChangesWholeWords() {
        XCTAssertEqual(edits("cat", "car"), "<delete>cat</delete><insert>car</insert>")
        XCTAssertEqual(edits("The cat sat.", "The car sat."), "The <delete>cat</delete><insert>car</insert> sat.")
    }

    /// Text that's only added, or only taken away, is just inserted or deleted.
    func testInsertsAndDeletes() {
        XCTAssertEqual(edits("Take the key.", "Take the brass key."), "Take the <insert>brass </insert>key.")
        XCTAssertEqual(edits("Take the brass key.", "Take the key."), "Take the <delete>brass </delete>key.")
        XCTAssertEqual(edits("Hello", "Hello "), "Hello<insert> </insert>")
    }

    /// A long enough run in common is kept, and the text either side of it is compared.
    func testKeepsTheLongestRunInCommon() {
        XCTAssertEqual(edits("alpha bravo charlie delta", "zulu bravo charlie yankee"),
                       "<delete>alpha</delete><insert>zulu</insert> bravo charlie <delete>delta</delete><insert>yankee</insert>")
    }

    /// A run of fewer than five characters isn't worth keeping.
    func testShortRunsInCommonAreNotKept() {
        XCTAssertEqual(edits("xx ab yy", "zz ab ww"), "<delete>xx ab yy</delete><insert>zz ab ww</insert>")
        XCTAssertEqual(edits("xx abc yy", "zz abc ww"),
                       "<delete>xx</delete><insert>zz</insert> abc <delete>yy</delete><insert>ww</insert>")
    }

    /// Accented letters are letters, so they don't end a word.
    func testAccentedLettersAreInWords() {
        XCTAssertEqual(edits("Café au lait", "Café noir"), "Café <delete>au lait</delete><insert>noir</insert>")
        XCTAssertEqual(edits("naïve", "naïf"), "<delete>naïve</delete><insert>naïf</insert>")
    }

    /// A character beyond 0xFFFF, such as an emoji, takes two UTF-16 units, and they're kept together.
    func testKeepsSurrogatePairsWhole() {
        XCTAssertEqual(edits("I see 😀 here", "I see 😢 here"), "I see <delete>😀</delete><insert>😢</insert> here")
    }

    /// Each diff starts afresh.
    func testADifferCanBeUsedAgain() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal("one", actual: "two"))
        XCTAssertFalse(differ.diffIdeal("same", actual: "same"))
        XCTAssertEqual(differ.differences.count, 0)
        XCTAssertTrue(differ.diffIdeal("cat", actual: "car"))
        XCTAssertEqual(render(differ), "<delete>cat</delete><insert>car</insert>")
    }
}
