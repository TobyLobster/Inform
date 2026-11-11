//
//  IFDocParserTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFDocParserTests: XCTestCase {

    private func text(_ html: String) -> String {
        return IFDocParser(html: html).plainText
    }

    // MARK: - The text

    /// A run of whitespace is one space, and whitespace at the start goes.
    func testCollapsesWhitespace() {
        XCTAssertEqual(text("  one \n\t two  "), "one two ")
    }

    /// A tag separates the text either side of it.
    func testATagSeparatesTheTextEitherSideOfIt() {
        XCTAssertEqual(text("a<b>b</b>c"), "a b c")
        XCTAssertEqual(text("a <i>b</i> c"), "a b c")
    }

    /// A line break, or the start or end of a paragraph, starts a new line.
    func testLineAndParagraphBreaksStartNewLines() {
        XCTAssertEqual(text("one<br>two<p>three</p>"), "one \ntwo \nthree \n")
        XCTAssertEqual(text("one<BR />two<p class=\"x\">three"), "one \ntwo \nthree")
    }

    /// The head, with its title, and scripts aren't part of the text.
    func testLeavesOutTheHeadAndScripts() {
        XCTAssertEqual(text("<head><title>T</title><style>x</style></head>a<script>var b;</script>c"), "a c")
    }

    func testLeavesOutComments() {
        XCTAssertEqual(text("a<!-- b -- c -->d"), "a d")
        XCTAssertEqual(text("<!DOCTYPE html>a"), "a")
    }

    func testDecodesEntities() {
        XCTAssertEqual(text("&lt;a&gt; &quot;b&quot;&nbsp;c &LT;"), "<a> \"b\" c <")
    }

    /// An ampersand, and a character given by its number in decimal or hex, as in the documentation.
    /// A numbered non-breaking space is a space, as &nbsp; is.
    func testDecodesAmpersandsAndNumberedCharacters() {
        XCTAssertEqual(text("US News &amp; World Report"), "US News & World Report")
        XCTAssertEqual(text("A&#38;E &#x2318;-R &#X41;"), "A&E \u{2318}-R A")
        XCTAssertEqual(text("&#160;&#160;say"), "  say")
        XCTAssertEqual(text("&#128512;!"), "\u{1F600}!")
        XCTAssertEqual(text("a&#0;&#xD800;&#x110000;&#12z;b"), "ab")
    }

    /// The marked parts that the search leaves out.
    func testLeavesOutIgnoredSections() {
        XCTAssertEqual(text("a<!--START IGNORE-->b<br>c<!--END IGNORE-->d"), "a d")
    }

    // MARK: - The attributes

    func testReadsTheTitle() {
        let parser = IFDocParser(html: "<head><title>  A   title </title></head>text")
        XCTAssertEqual(parser.attributes[.htmlTitle] as? String, "A title ")
        XCTAssertEqual(IFDocParser(html: "text").attributes[.htmlTitle] as? String, "")
    }

    /// An entity it doesn't know is left out of the title, as it is from the text.
    func testLeavesAnEntityItDoesNotKnowOutOfTheTitle() {
        let parser = IFDocParser(html: "<head><title>a&bull;b</title></head>a&bull;b")
        XCTAssertEqual(parser.attributes[.htmlTitle] as? String, "ab")
        XCTAssertEqual(parser.plainText, "ab")
    }

    /// The search title and section are given in comments.
    func testReadsTheSearchTitleAndSection() {
        let parser = IFDocParser(html: #"<!--SEARCH TITLE "Pattern matching"--><!--SEARCH SECTION "11.3"-->text"#)
        XCTAssertEqual(parser.attributes[.title] as? String, "Pattern matching")
        XCTAssertEqual(parser.attributes[.section] as? String, "11.3")
        XCTAssertNil(IFDocParser(html: "text").attributes[.title])
    }

    /// So is the key that Find in Files sorts the pages by.
    func testReadsTheSortKey() {
        let parser = IFDocParser(html: #"<!--SEARCH SORT "000-011-003-000"-->text"#)
        XCTAssertEqual(parser.attributes[.sort] as? String, "000-011-003-000")
    }

    /// A marker without the quoted text it should have is passed over.
    func testPassesOverAMarkerWithoutItsText() {
        let parser = IFDocParser(html: #"a<!--START CODE-->b<!--END CODE--><!--START PHRASE-->c<!--SEARCH TITLE "-->d"#
                                     + #"<!--START EXAMPLE "-->e<!--SEARCH SECTION "-->"#)
        XCTAssertEqual(parser.plainText, "a b c d e ")
        XCTAssertNil(parser.attributes[.title])
        XCTAssertNil(parser.attributes[.section])
    }

    // MARK: - Examples, code and definitions

    /// An example's name, anchor and range in the text; the first of a name is kept.
    func testReadsExamples() {
        let parser = IFDocParser(html: #"a<!--START EXAMPLE "101: A&E" "e8"-->in example<!--END EXAMPLE-->b"#
                                     + #"<!--START EXAMPLE "101: A&E" "e9"-->again<!--END EXAMPLE-->"#)
        XCTAssertEqual(parser.plainText, "a in example b again ")
        XCTAssertEqual(parser.exampleInfo.count, 1)
        let example = parser.exampleInfo["101: A&E"]
        XCTAssertEqual(example?.name, "101: A&E")
        XCTAssertEqual(example?.anchorTag, "e8")
        XCTAssertEqual(example?.range, NSRange(location: 2, length: 11))
    }

    /// Code and definitions (phrases) are listed in order, with their anchors and ranges in the text.
    func testReadsCodeAndDefinitions() {
        let parser = IFDocParser(html: #"a<!--START CODE "c1"-->code<!--END CODE-->b"#
                                     + #"<!--START PHRASE "p1"-->phrase<!--END PHRASE-->"#
                                     + #"<!--START CODE "c2"-->more<!--END CODE-->"#)
        XCTAssertEqual(parser.plainText, "a code b phrase more ")
        XCTAssertEqual(parser.codeInfo.map { $0.anchorTag }, ["c1", "c2"])
        XCTAssertEqual(parser.codeInfo.map { $0.range }, [NSRange(location: 2, length: 5), NSRange(location: 16, length: 5)])
        XCTAssertEqual(parser.definitionInfo.map { $0.anchorTag }, ["p1"])
        XCTAssertEqual(parser.definitionInfo.map { $0.range }, [NSRange(location: 9, length: 7)])
    }

    // MARK: - A page of the documentation

    /// A page of Writing with Inform, as Find in Files searches it.
    func testReadsADocumentationPage() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "doc159", withExtension: "html"))
        let parser = IFDocParser(html: try String(contentsOf: url, encoding: .utf8))

        XCTAssertEqual(parser.attributes[.htmlTitle] as? String, "11.3. Pattern matching")
        XCTAssertEqual(parser.attributes[.title] as? String, "Pattern matching")
        XCTAssertEqual(parser.attributes[.section] as? String, "11.3")
        XCTAssertEqual(parser.attributes[.sort] as? String, "000-011-003-000")
        XCTAssertFalse(parser.plainText.contains("<"))

        XCTAssertEqual(parser.exampleInfo.keys.sorted(), ["169: Ahem", "170: Ferragamo Again"])
        XCTAssertEqual(parser.exampleInfo["169: Ahem"]?.anchorTag, "e12")
        XCTAssertEqual(parser.exampleInfo["169: Ahem"]?.range, NSRange(location: 3939, length: 1526))

        XCTAssertEqual(parser.codeInfo.count, 39)
        XCTAssertEqual(parser.definitionInfo.count, 0)
        let firstCode = try XCTUnwrap(parser.codeInfo.first)
        XCTAssertEqual(firstCode.anchorTag, "c2817")
        XCTAssertEqual((parser.plainText as NSString).substring(with: firstCode.range),
                       "\nTo admire (item - an object): \n    say \"You take a long look at [item].\". \n")
    }
}
