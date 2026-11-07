//
//  IFHeaderTests.swift
//  InformTests
//

import XCTest

final class IFHeaderTests: XCTestCase {

    private func header(_ name: String, parent: IFHeader? = nil, children: [IFHeader]? = nil) -> IFHeader {
        return IFHeader(name: name, parent: parent, children: children)
    }

    func testAHeaderHasTheNameAndParentItWasMadeWith() {
        let part = header("Part 1")
        let chapter = header("Chapter 1", parent: part)

        XCTAssertEqual(chapter.headingName, "Chapter 1")
        XCTAssertIdentical(chapter.parent, part)
        XCTAssertNil(part.parent)
        XCTAssertEqual(chapter.children, [])
        XCTAssertNil(chapter.symbol)
    }

    /// The children it's made with are its children, and it's their parent
    func testAHeaderIsTheParentOfItsChildren() {
        let first = header("Section 1")
        let second = header("Section 2")
        let chapter = header("Chapter 1", children: [first, second])

        XCTAssertEqual(chapter.children, [first, second])
        XCTAssertIdentical(first.parent, chapter)
        XCTAssertIdentical(second.parent, chapter)
    }

    /// Setting the children makes it their parent, and the children it had lose their parent
    func testSettingTheChildrenChangesTheirParents() {
        let first = header("Section 1")
        let second = header("Section 2")
        let third = header("Section 3")
        let chapter = header("Chapter 1", children: [first, second])

        chapter.children = [third, second]

        XCTAssertEqual(chapter.children, [third, second])
        XCTAssertNil(first.parent)
        XCTAssertIdentical(second.parent, chapter)
        XCTAssertIdentical(third.parent, chapter)

        chapter.children = []
        XCTAssertEqual(chapter.children, [])
        XCTAssertNil(second.parent)
        XCTAssertNil(third.parent)
    }

    /// A header doesn't keep its parent
    func testAHeaderLosesItsParentWhenNothingElseKeepsIt() {
        let section = header("Section 1")
        autoreleasepool {
            let chapter = header("Chapter 1", children: [section])
            XCTAssertIdentical(section.parent, chapter)
        }
        XCTAssertNil(section.parent)
    }

    /// Its name, parent and symbol can be changed
    func testAHeadersNameParentAndSymbolCanBeChanged() {
        let chapter = header("Chapter 1")
        let part = header("Part 1")
        let symbol = IFIntelSymbol()
        symbol.name = "Chapter 2"

        chapter.headingName = "Chapter 2"
        chapter.parent = part
        chapter.symbol = symbol

        XCTAssertEqual(chapter.headingName, "Chapter 2")
        XCTAssertIdentical(chapter.parent, part)
        XCTAssertIdentical(chapter.symbol, symbol)
        // Setting a parent doesn't make it a child
        XCTAssertEqual(part.children, [])
    }

    /// Its name is a copy of the one it's given (set through key-value coding, as Swift would copy it anyway)
    func testAHeaderCopiesItsName() {
        let chapter = header("Chapter 1")
        let name = NSMutableString(string: "Chapter 2")
        chapter.setValue(name, forKey: "headingName")
        name.setString("Chapter 3")
        XCTAssertEqual(chapter.headingName, "Chapter 2")
    }
}
