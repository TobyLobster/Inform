//
//  IFUtilityTests.swift
//  InformTests
//

import XCTest
import UniformTypeIdentifiers

final class IFUtilityTests: XCTestCase {

    func testContentTypesForKnownExtensions() {
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: ["txt", "rtf"])
        XCTAssertEqual(types.count, 2)
        XCTAssertTrue(types[0].conforms(to: .plainText))
        XCTAssertTrue(types[1].conforms(to: .rtf))
    }

    func testContentTypesForUnknownExtensionMatchTheExtension() {
        // An extension no app declares still gives a (dynamic) type, which panels match by extension
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: ["zoomSave"])
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types[0].preferredFilenameExtension?.lowercased(), "zoomsave")
    }

    func testContentTypesKeepOrder() {
        let extensions = ["rec", "txt", "zoomSave", "skein"]
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: extensions)
        XCTAssertEqual(types.count, extensions.count)
        XCTAssertTrue(types[1].conforms(to: .plainText))
    }

    func testContentTypesForNoExtensions() {
        XCTAssertEqual(IFUtility.contentTypes(forFilenameExtensions: [])?.count, 0)
    }
}
