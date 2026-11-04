//
//  IFSkeinXMLTests.swift
//  InformTests
//

import XCTest

final class IFSkeinXMLTests: XCTestCase {

    /// A skein in the format Zoom saved, as found in older projects.
    private let zoomSkein = """
        <?xml version="1.0"?>
        <Skein rootNode="node-0x1" xmlns="http://www.logicalshift.org.uk/IF/Skein">
          <generator>Zoom</generator>
          <activeNode nodeId="node-0x3" />
          <item nodeId="node-0x1">
            <command xml:space="preserve">- start -</command>
            <result xml:space="preserve">Low Pitched Corridor

        &gt;</result>
            <played>YES</played>
            <changed>NO</changed>
            <temporary score="5">NO</temporary>
            <children>
              <child nodeId="node-0x2" />
              <child nodeId="node-0x3" />
            </children>
          </item>
          <item nodeId="node-0x2">
            <command xml:space="preserve">x me</command>
            <result xml:space="preserve">As good-looking as ever.

        &gt;</result>
            <commentary xml:space="preserve">As handsome as ever.</commentary>
          </item>
          <item nodeId="node-0x3">
            <command xml:space="preserve">north</command>
            <annotation xml:space="preserve">*** You have won ***</annotation>
          </item>
        </Skein>
        """

    /// Writes a skein as XML and reads it back into a new skein.
    private func roundTrip(_ skein: IFSkein) throws -> IFSkein {
        let xml = try XCTUnwrap(skein.xmlString)
        let copy: IFSkein = IFSkein(project: nil)
        XCTAssertTrue(copy.parseXmlData(Data(xml.utf8)), xml)
        return copy
    }

    /// Checks that two skeins have the same items, in the same order.
    private func assertSameItems(_ a: IFSkeinItem, _ b: IFSkeinItem, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.command, b.command, file: file, line: line)
        XCTAssertEqual(a.actual, b.actual, a.command, file: file, line: line)
        XCTAssertEqual(a.ideal, b.ideal, a.command, file: file, line: line)
        XCTAssertEqual(a.isTestSubItem, b.isTestSubItem, a.command, file: file, line: line)
        XCTAssertEqual(a.children.map { $0.command }, b.children.map { $0.command }, a.command, file: file, line: line)
        for (childA, childB) in zip(a.children, b.children) {
            XCTAssertTrue(childB.parent === b, file: file, line: line)
            assertSameItems(childA, childB, file: file, line: line)
        }
    }

    func testReadsAZoomSkein() throws {
        let skein: IFSkein = IFSkein(project: nil)
        XCTAssertTrue(skein.parseXmlData(Data(zoomSkein.utf8)))

        let root: IFSkeinItem = skein.rootItem
        XCTAssertEqual(root.command, "- start -")
        XCTAssertEqual(root.actual, "Low Pitched Corridor\n\n>")
        // An item's children are kept in alphabetical order
        XCTAssertEqual(root.children.map { $0.command }, ["north", "x me"])

        let look: IFSkeinItem = root.children[1]
        XCTAssertTrue(look.parent === root)
        XCTAssertEqual(look.actual, "As good-looking as ever.\n\n>")
        XCTAssertEqual(look.ideal, "As handsome as ever.")

        let north: IFSkeinItem = root.children[0]
        XCTAssertEqual(north.actual, "")
        XCTAssertTrue(skein.winningItem === north)
    }

    func testRejectsASkeinWithoutARoot() {
        let skein: IFSkein = IFSkein(project: nil)
        XCTAssertFalse(skein.parseXmlData(Data("<Skein><item nodeId=\"node-1\"/></Skein>".utf8)))
        XCTAssertFalse(skein.parseXmlData(Data("<Skein rootNode=\"node-2\"><item nodeId=\"node-1\"/></Skein>".utf8)))
        XCTAssertFalse(skein.parseXmlData(Data("not XML".utf8)))
    }

    /// Commands, transcripts and ideal transcripts survive being saved and loaded, including
    /// markup characters, accents, and leading, trailing and repeated white space.
    func testWritesWhatItReads() throws {
        let skein: IFSkein = IFSkein(project: nil)
        skein.rootItem.actual = "Library\nYou can see a <b> & a \"quote\".\n\n>"
        let first: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "say \"café\" & <hello>"))
        first.actual = "  You say it.\n\n\n>"
        first.ideal = "You say it.\n>"
        let second: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "wait"))
        second.actual = "Time passes.\t\n>"
        let third: IFSkeinItem = second.addChild(IFSkeinItem(skein: skein, command: "z"))
        skein.winningItem = third

        let copy = try roundTrip(skein)
        assertSameItems(skein.rootItem, copy.rootItem)
        XCTAssertEqual(copy.winningItem?.command, "z")
        XCTAssertTrue(copy.winningItem?.parent?.parent === copy.rootItem)
    }

    /// A "test me" style command is saved as one item with its whole transcript, and split up
    /// again into an item for each command when it's loaded.
    func testWritesAndReadsTestCommands() throws {
        let transcript = "(Testing.)\n\n>[1] look\nLibrary\n\n>[2] jump\nYou jump on the spot.\n\n>"
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        test.actual = transcript
        _ = test.addChild(IFSkeinItem(skein: skein, command: "wait"))
        _ = test.decompose

        XCTAssertEqual(test.children.map { $0.command }, ["look"])
        XCTAssertEqual(test.nonTestChildren?.map { $0.command }, ["wait"])
        XCTAssertEqual(test.composedActual, transcript)

        let copy = try roundTrip(skein)
        assertSameItems(skein.rootItem, copy.rootItem)
        let copiedTest: IFSkeinItem = copy.rootItem.children[0]
        XCTAssertEqual(copiedTest.composedActual, transcript)
        XCTAssertTrue(copiedTest.children[0].isTestSubItem)
    }
}
