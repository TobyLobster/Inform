//
//  IFSyntaxColouringOptionTests.swift
//  InformTests
//

import XCTest

/// Archived under IFSyntaxColouringOption's name with only the colours given, to make a damaged archive
@objc(IFSyntaxColouringOptionTestsPartialOption)
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

@MainActor
final class IFSyntaxColouringOptionTests: XCTestCase {

    private let red = NSColor(deviceRed: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
    private let blue = NSColor(deviceRed: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)

    private func archive(_ object: Any, as className: String? = nil) throws -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        if let className {
            archiver.setClassName(className, for: PartialOption.self)
        }
        archiver.encode(object, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private func unarchive(_ data: Data) throws -> IFSyntaxColouringOption? {
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: IFSyntaxColouringOption.self, from: data)
    }

    /// An option starts with its colour as its default
    func testAnOptionStartsWithItsDefaultColour() {
        let option = IFSyntaxColouringOption(colour: red)
        XCTAssertEqual(option.colour, red)
        XCTAssertEqual(option.defaultColour, red)

        option.colour = blue
        XCTAssertEqual(option.colour, blue)
        XCTAssertEqual(option.defaultColour, red)
    }

    /// ...which is black if it's not given one, as a new colour theme's options are
    func testAnOptionIsBlackIfNotGivenAColour() {
        let option = IFSyntaxColouringOption()
        XCTAssertEqual(option.colour, NSColor.black)
        XCTAssertEqual(option.defaultColour, NSColor.black)
    }

    /// A copy has the same colours, and changing it leaves the original alone
    func testACopyHasTheSameColours() throws {
        let option = IFSyntaxColouringOption(colour: red)
        option.colour = blue

        let copy = try XCTUnwrap(option.copy() as? IFSyntaxColouringOption)

        XCTAssertNotIdentical(copy, option)
        XCTAssertEqual(copy.colour, blue)
        XCTAssertEqual(copy.defaultColour, red)
        copy.colour = red
        XCTAssertEqual(option.colour, blue)
    }

    /// Themes are kept in the preferences as a secure archive
    func testAnOptionIsArchivedWithItsColours() throws {
        let option = IFSyntaxColouringOption(colour: red)
        option.colour = blue

        let read = try XCTUnwrap(try unarchive(try archive(option)))

        XCTAssertEqual(read.colour, blue)
        XCTAssertEqual(read.defaultColour, red)
        XCTAssertTrue(IFSyntaxColouringOption.supportsSecureCoding)
    }

    /// An archived option with a colour missing reads as nothing, rather than stopping the app, so that a damaged
    /// theme in the preferences can be left out, as the preferences leave out a theme with no paper colour. (At the
    /// top of an archive, nothing is an error.)
    func testAnArchivedOptionWithAColourMissingReadsAsNothing() throws {
        XCTAssertNil(try? unarchive(try archive(PartialOption(["defaultColour": red]), as: "IFSyntaxColouringOption")))
        XCTAssertNil(try? unarchive(try archive(PartialOption(["colour": red]), as: "IFSyntaxColouringOption")))
    }
}
